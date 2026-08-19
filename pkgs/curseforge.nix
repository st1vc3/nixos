{
  lib,
  appimageTools,
  fetchurl,
}:

# CurseForge is not in nixpkgs (it is proprietary, and Overwolf ships only
# prebuilt binaries), so this repackages the official Linux AppImage. It is an
# Electron app, so appimageTools' FHS wrapper supplies the Chromium runtime
# rather than us patching the binary.
#
# Upstream publishes no versioned download URL - "curseforge-latest-linux" is
# the only path there is. That makes the pinned hash a tripwire rather than a
# pin: when Overwolf ships a new build, the fetch fails with a hash mismatch
# and the rebuild stops. That is the honest failure mode for an unversioned
# source (the alternative is silently installing whatever is upstream today),
# but it does mean this derivation needs a manual version + hash bump whenever
# it breaks. To bump:
#
#   nix-prefetch-url https://curseforge.overwolf.com/downloads/curseforge-latest-linux.AppImage
#   nix hash convert --hash-algo sha256 --to sri <the base32 output>
#
# and read the new version out of the extracted curseforge.desktop
# (X-AppImage-Version).
let
  pname = "curseforge";
  version = "1.316.0-37372";

  src = fetchurl {
    url = "https://curseforge.overwolf.com/downloads/curseforge-latest-linux.AppImage";
    hash = "sha256-ZH4ZkFSoT8bQgcQPkszcux4gds4DHwrD7Vyub+13mgQ=";
  };

  # Unpacked separately so the desktop entry and icons can be installed into
  # the profile; the wrapper below only ever produces the executable.
  contents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -Dm444 ${contents}/${pname}.desktop -t $out/share/applications

    # The bundled entry launches the AppImage's own AppRun, which does not
    # exist once wrapped. Point it at the wrapper instead, keeping the
    # --no-sandbox flag upstream sets: the bundled chrome-sandbox is not
    # setuid root in the store, so Chromium refuses to start without it.
    substituteInPlace $out/share/applications/${pname}.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${pname}'

    # Ships a full hicolor set (16x16 through 1024x1024), so copy the tree
    # wholesale rather than picking one size for the launcher to upscale.
    cp -r ${contents}/usr/share/icons $out/share/
  '';

  meta = {
    description = "Mod and addon manager for World of Warcraft, Minecraft and other games";
    homepage = "https://www.curseforge.com/download/app";
    # Proprietary Overwolf software, redistributed as an unmodified binary.
    # configuration.nix already sets nixpkgs.config.allowUnfree.
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
