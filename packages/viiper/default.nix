{
  lib,
  stdenvNoCC,
  fetchurl,
  ...
}:

stdenvNoCC.mkDerivation rec {
  pname = "viiper";
  version = "0.9.0";

  src = fetchurl {
    url = "https://github.com/Alia5/VIIPER/releases/download/v${version}/viiper-linux-amd64";
    hash = "sha256-kiH4QNpGApZBcS7nxR1OM9H2BETGgU+gE7hZtLkcXwc=";
  };

  # Since 0.9.0 the release asset is the bare binary, not a tarball.
  dontUnpack = true;

  # Static Go binary — nothing to patch, just install.
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/bin/viiper

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
