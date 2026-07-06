{
  lib,
  stdenvNoCC,
  fetchurl,
  ...
}:

stdenvNoCC.mkDerivation rec {
  pname = "viiper";
  version = "0.7.0";

  src = fetchurl {
    url = "https://github.com/Alia5/VIIPER/releases/download/v${version}/viiper-linux-amd64.tar.gz";
    hash = "sha256-0NcyoA6mNvgr1oHg4gXK3Yj5WiFiDpWjSTp6JU0kENo=";
  };

  sourceRoot = ".";

  # Static Go binary — nothing to patch, just install.
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 viiper $out/bin/viiper
    install -Dm644 licenses.txt $out/share/doc/viiper/licenses.txt

    runHook postInstall
  '';

  meta = with lib; {
    description = "Virtual Input over IP EmulatoR — virtual USB input devices over USB/IP";
    homepage = "https://github.com/Alia5/VIIPER";
    changelog = "https://github.com/Alia5/VIIPER/releases/tag/v${version}";
    license = licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "viiper";
  };
}
