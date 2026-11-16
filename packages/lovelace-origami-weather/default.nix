{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation rec {
  pname = "lovelace-origami-weather";
  version = "1.6.1";

  src = fetchFromGitHub {
    owner = "hazymorning";
    repo = "origami_weather";
    rev = "V${version}";
    hash = "sha256-U24zKC63wxiAWAwMkwC58pCMhD1W0lC/k7m+8I/ztVY=";
  };

  dontBuild = true;

  # Since 1.6.1 the card ships as one bundle in dist/. It keeps its subdir so
  # the registered resource URL does not change.
  installPhase = ''
    runHook preInstall

    install -Dm644 dist/origami-weather.js $out/origami-weather/origami-weather.js

    runHook postInstall
  '';

  passthru.entrypoint = "origami-weather/origami-weather.js";

  meta = {
    description = "Animated weather card for the Origami Home Assistant dashboard";
    homepage = "https://github.com/hazymorning/origami_weather";
    license = lib.licenses.gpl3Only;
  };
}
