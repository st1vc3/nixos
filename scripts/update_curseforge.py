#!/usr/bin/env python3
"""Refresh the pinned CurseForge AppImage from its official download URL."""

import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import tempfile


URL = "https://curseforge.overwolf.com/downloads/curseforge-latest-linux.AppImage"


def appimage_offset(path):
    """Type 2 AppImages append SquashFS after their ELF section headers."""
    with path.open("rb") as image:
        header = image.read(64)
        if len(header) != 64 or header[:6] != b"\x7fELF\x02\x01":
            raise ValueError("download is not a little-endian 64-bit ELF AppImage")
        if header[8:11] != b"AI\x02":
            raise ValueError("download is not a type 2 AppImage")
        section_offset = struct.unpack_from("<Q", header, 40)[0]
        section_size, section_count = struct.unpack_from("<HH", header, 58)
        if not section_offset or not section_size or not section_count:
            raise ValueError("AppImage has no ELF section headers")
        offset = section_offset + section_size * section_count
        image.seek(offset)
        if image.read(4) != b"hsqs":
            raise ValueError("AppImage has no SquashFS filesystem at its ELF boundary")
        return offset


def desktop_version(desktop):
    matches = re.findall(r"^X-AppImage-Version=(.+)$", desktop, re.MULTILINE)
    if len(matches) != 1:
        raise ValueError(
            "expected exactly one X-AppImage-Version in curseforge.desktop"
        )
    # Upstream repeats the build number after a dot in its desktop metadata.
    match = re.fullmatch(r"(\d+\.\d+\.\d+-(\d+))(?:\.\2)?", matches[0])
    if not match:
        raise ValueError(f"unrecognized CurseForge version: {matches[0]!r}")
    return match[1]


def refreshed_expression(expression, version, digest):
    if not re.fullmatch(r"sha256-[A-Za-z0-9+/]{43}=", digest):
        raise ValueError("prefetch returned an invalid SHA-256 hash")
    urls = re.findall(r'\burl = "([^"]+)";', expression)
    if urls != [URL]:
        raise ValueError("CurseForge derivation does not use the expected official URL")
    for field, value in (("version", version), ("hash", digest)):
        expression, count = re.subn(
            rf'(\b{field} = ")[^"]+(";)',
            lambda match: match[1] + value + match[2],
            expression,
        )
        if count != 1:
            raise ValueError(f"expected exactly one {field} assignment")
    return expression


def update(repo):
    target = repo / "pkgs/curseforge.nix"
    original = target.read_text()
    # Nix retains the downloaded bytes in the store, allowing the subsequent
    # build to reuse exactly the content whose hash and version we inspected.
    fetched = json.loads(
        subprocess.check_output(
            [
                "nix",
                "store",
                "prefetch-file",
                "--json",
                "--name",
                "curseforge-latest-linux.AppImage",
                URL,
            ],
            text=True,
        )
    )
    image = Path(fetched["storePath"])
    offset = appimage_offset(image)
    with tempfile.TemporaryDirectory(prefix="curseforge-update-") as scratch:
        destination = Path(scratch) / "contents"
        subprocess.run(
            [
                "unsquashfs",
                "-no-progress",
                "-o",
                str(offset),
                "-d",
                str(destination),
                str(image),
                "curseforge.desktop",
            ],
            check=True,
            stdout=subprocess.DEVNULL,
        )
        desktop = destination / "curseforge.desktop"
        if desktop.is_symlink() or not desktop.is_file():
            raise ValueError("AppImage is missing a regular curseforge.desktop file")
        version = desktop_version(desktop.read_text())
    updated = refreshed_expression(original, version, fetched["hash"])
    if updated == original:
        print(f"CurseForge {version} is already up to date.")
        return
    # Write beside the destination and rename only after all validation passes.
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", dir=target.parent, delete=False
        ) as output:
            temporary = Path(output.name)
            output.write(updated)
        temporary.chmod(target.stat().st_mode & 0o777)
        if target.read_text() != original:
            raise ValueError("CurseForge derivation changed during the update; retry")
        os.replace(temporary, target)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    print(f"Updated CurseForge to {version} ({fetched['hash']}).")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: update-curseforge <nixos-repository>")
    try:
        update(Path(sys.argv[1]).resolve())
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        sys.exit(f"CurseForge update failed: {error}")
