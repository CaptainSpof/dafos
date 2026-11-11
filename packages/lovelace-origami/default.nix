{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation rec {
  pname = "lovelace-origami";
  version = "3.0";

  src = fetchFromGitHub {
    owner = "hazymorning";
    repo = "origami";
    rev = "V${version}";
    hash = "sha256-GncMXdoLFGJ5TmVRweQVdQYNIMiWUqWK9N7U3Zv6ABI=";
  };

  dontBuild = true;

  # Only the Montserrat font is served from www/. Upstream's stylesheet points
  # at /local/fonts/, so it is rewritten to load the fonts next to it. Nested
  # under one subdir so buildEnv, which flattens every customLovelaceModule into
  # a single served directory, can't collide with another card's files.
  #
  # The NixOS module registers every entrypoint as a JS module, and a browser
  # refuses a stylesheet loaded that way (the font never loaded with 2.0). So
  # the entrypoint is a one-line script that adds the stylesheet to the page.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/origami
    cp -v www/fonts/*.woff2 www/fonts/OFL.txt $out/origami/
    substitute www/fonts/montserrat.css $out/origami/montserrat.css \
      --replace-fail "url('/local/fonts/" "url('./"
    cat > $out/origami/montserrat.js <<'EOF'
    document.head.append(Object.assign(document.createElement("link"), { rel: "stylesheet", href: new URL("./montserrat.css", import.meta.url).href }));
    EOF

    runHook postInstall
  '';

  passthru = {
    entrypoint = "origami/montserrat.js";
    # Read straight from the source, not served: the theme for frontend.themes
    # and the Bubble Card modules copied into /var/lib/hass/bubble_card/modules.
    # Since 3.0 the modules take their words from Home Assistant, so the state
    # lines are French without a patch.
    themes = "${src}/themes";
    bubbleCardModules = "${src}/bubble_card/modules";
  };

  meta = {
    description = "Origami theme, font and Bubble Card modules for Home Assistant";
    homepage = "https://github.com/hazymorning/origami";
    license = lib.licenses.agpl3Only;
  };
}
