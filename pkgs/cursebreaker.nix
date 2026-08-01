{ stdenv, lib, fetchurl, autoPatchelfHook, gzip, zlib }:

stdenv.mkDerivation rec {
  pname = "cursebreaker";
  version = "4.8.4";

  src = fetchurl {
    url = "https://github.com/AcidWeb/CurseBreaker/releases/download/v${version}/CurseBreaker-linux.gz";
    hash = "sha256:1q4hwfm44h188j1w181apiimdfyh1am24zddyiq473idi20fgxdz";
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib zlib ];

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/bin
    ${gzip}/bin/gunzip -c $src > $out/bin/cursebreaker
    chmod +x $out/bin/cursebreaker
  '';

  meta = {
    description = "CLI addon manager for World of Warcraft";
    homepage = "https://github.com/AcidWeb/CurseBreaker";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "cursebreaker";
  };
}
