{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation rec {
  pname = "lovelace-origami-weather";
  version = "1.6";

  src = fetchFromGitHub {
    owner = "hazymorning";
    repo = "origami_weather";
    rev = "V${version}";
    hash = "sha256-ymtSQRfvdWf+XUjqIQ+QD5WxUs0L1znRRHGp0Uboxgk=";
  };

  dontBuild = true;

  # The card imports its assets, presets and editor by relative URL, so they
  # sit next to it, nested under one subdir like lovelace-idf-mobilite.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/origami-weather
    cp -v *.js $out/origami-weather/

    runHook postInstall
  '';

  passthru.entrypoint = "origami-weather/origami-weather.js";

  meta = {
    description = "Animated weather card for the Origami Home Assistant dashboard";
    homepage = "https://github.com/hazymorning/origami_weather";
    license = lib.licenses.gpl3Only;
  };
}
