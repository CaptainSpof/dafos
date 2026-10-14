{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation rec {
  pname = "lovelace-origami";
  version = "2.0";

  src = fetchFromGitHub {
    owner = "hazymorning";
    repo = "origami";
    rev = "V${version}";
    hash = "sha256-EdhctMxlQeCLcQ5vd2ANkxBTiF8f/zojakI98QOV1gM=";
  };

  dontBuild = true;

  # Only the Montserrat font is served from www/. Upstream's stylesheet points
  # at /local/fonts/, so it is rewritten to load the fonts next to it. Nested
  # under one subdir so buildEnv, which flattens every customLovelaceModule into
  # a single served directory, can't collide with another card's files.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/origami
    cp -v www/fonts/*.woff2 www/fonts/OFL.txt $out/origami/
    substitute www/fonts/montserrat.css $out/origami/montserrat.css \
      --replace-fail "url('/local/fonts/" "url('./"

    runHook postInstall
  '';

  passthru = {
    entrypoint = "origami/montserrat.css";
    # Read straight from the source, not served: the theme for frontend.themes
    # and the Bubble Card modules copied into /var/lib/hass/bubble_card/modules.
    themes = "${src}/themes";
    bubbleCardModules = "${src}/bubble_card/modules";
  };

  meta = {
    description = "Origami theme, font and Bubble Card modules for Home Assistant";
    homepage = "https://github.com/hazymorning/origami";
    license = lib.licenses.agpl3Only;
  };
}
