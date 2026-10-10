"""Run with: python3 -m unittest discover -s scripts -p 'test_*.py'."""

import contextlib
import io
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

import update_curseforge as updater


class CurseForgeUpdaterTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.addCleanup(self.scratch.cleanup)
        self.repo = Path(self.scratch.name)
        (self.repo / "pkgs").mkdir()
        self.target = self.repo / "pkgs/curseforge.nix"
        self.original = (
            'version = "1.321.1-39714";\n'
            f'url = "{updater.URL}";\n'
            f'hash = "sha256-{"A" * 43}=";\n'
        )
        self.target.write_text(self.original)
        self.target.chmod(0o644)
        self.digest = "sha256-" + "B" * 43 + "="
        self.image = self.repo / "download.AppImage"
        header = bytearray(64)
        header[:6] = b"\x7fELF\x02\x01"
        header[8:11] = b"AI\x02"
        struct.pack_into("<Q", header, 40, 64)
        struct.pack_into("<HH", header, 58, 64, 1)
        self.image.write_bytes(header + bytes(64) + b"hsqs")

    def extract(self, command, **kwargs):
        destination = Path(command[command.index("-d") + 1])
        destination.mkdir()
        (destination / "curseforge.desktop").write_text(
            "[Desktop Entry]\nX-AppImage-Version=1.322.0-40357.40357\n"
        )

    def run_update(self, extract=None):
        fetched = json.dumps({"storePath": str(self.image), "hash": self.digest})
        with (
            patch.object(updater.subprocess, "check_output", return_value=fetched),
            patch.object(
                updater.subprocess, "run", side_effect=extract or self.extract
            ),
            contextlib.redirect_stdout(io.StringIO()),
        ):
            updater.update(self.repo)

    def test_success_updates_both_fields_and_preserves_mode(self):
        self.run_update()
        self.assertIn('version = "1.322.0-40357";', self.target.read_text())
        self.assertIn(self.digest, self.target.read_text())
        self.assertEqual(self.target.stat().st_mode & 0o777, 0o644)

    def test_repeat_update_does_not_rewrite_file(self):
        self.run_update()
        before = self.target.stat()
        self.run_update()
        after = self.target.stat()
        self.assertEqual(
            (before.st_ino, before.st_mtime_ns), (after.st_ino, after.st_mtime_ns)
        )

    def test_invalid_download_leaves_file_untouched(self):
        self.image.write_bytes(b"<html>download unavailable</html>")
        with self.assertRaises(ValueError):
            self.run_update()
        self.assertEqual(self.target.read_text(), self.original)

    def test_extraction_failure_leaves_file_untouched(self):
        def fail(command, **kwargs):
            raise updater.subprocess.CalledProcessError(1, command)

        with self.assertRaises(updater.subprocess.CalledProcessError):
            self.run_update(fail)
        self.assertEqual(self.target.read_text(), self.original)

    def test_missing_desktop_leaves_file_untouched(self):
        with self.assertRaises(ValueError):
            self.run_update(lambda *args, **kwargs: None)
        self.assertEqual(self.target.read_text(), self.original)

    def test_concurrent_edit_is_preserved(self):
        def concurrent_edit(command, **kwargs):
            self.extract(command, **kwargs)
            self.target.write_text(self.original + "# concurrent edit\n")

        with self.assertRaisesRegex(ValueError, "changed during"):
            self.run_update(concurrent_edit)
        self.assertEqual(self.target.read_text(), self.original + "# concurrent edit\n")
        self.assertEqual(list(self.target.parent.iterdir()), [self.target])

    def test_rejects_wrong_download_url(self):
        expression = self.original.replace(updater.URL, "https://example.com/app")
        with self.assertRaises(ValueError):
            updater.refreshed_expression(expression, "1.322.0-40357", self.digest)

    def test_rejects_ambiguous_assignments(self):
        with self.assertRaises(ValueError):
            updater.refreshed_expression(
                self.original + 'version = "2.0.0-1";\n', "1.322.0-40357", self.digest
            )

    def test_rejects_invalid_hash(self):
        with self.assertRaises(ValueError):
            updater.refreshed_expression(self.original, "1.322.0-40357", "bad-hash")

    def test_version_validation(self):
        for version in ("1.322.0-40357", "1.322.0-40357.40357"):
            self.assertEqual(
                updater.desktop_version(f"X-AppImage-Version={version}\n"),
                "1.322.0-40357",
            )
        for desktop in (
            "X-AppImage-Version=unexpected\n",
            "X-AppImage-Version=1.322.0-40357.999\n",
            "[Desktop Entry]\n",
            "X-AppImage-Version=1.0.0-1\nX-AppImage-Version=2.0.0-2\n",
        ):
            with self.assertRaises(ValueError):
                updater.desktop_version(desktop)


if __name__ == "__main__":
    unittest.main()
