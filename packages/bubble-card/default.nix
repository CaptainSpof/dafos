{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation {
  pname = "bubble-card";
  name = "bubble-card";
  version = "2.5.0-beta.5";

  src = fetchFromGitHub {
    owner = "Clooos";
    repo = "bubble-card";
    rev = "02b3bdfd2753f7b6582241ebc6404ddb74a37a21";
    sha256 = "sha256-HCRSECN9KaN9+VnjzoVOv6rIypTgtalz+jiGwKmt3WY=";
  };

  installPhase = ''
    runHook preInstall

    mkdir $out
    install -m0644 dist/bubble-card.js $out
    install -m0644 dist/bubble-pop-up-fix.js $out

    runHook postInstall
  '';

  meta = {
    description = "";
    homepage = "";
    license = lib.licenses.gpl3;
    platforms = lib.platforms.linux;
  };
}
