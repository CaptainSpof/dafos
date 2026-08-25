{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation rec {
  pname = "lovelace-idf-mobilite";
  version = "0.4.5";

  src = fetchFromGitHub {
    owner = "yyrkoon94";
    repo = "lovelace-idf-mobilite";
    rev = "v${version}";
    hash = "sha256-zoH4ZD/vFtL0anFKt6GiSSWaI5FEL+qXpc/eKaCHvNg=";
  };

  dontBuild = true;

  # Ship the whole prebuilt dist/ tree: the entrypoint pulls in its editor,
  # line referential, and the parser/render/images subdirs by *relative* URL
  # (./parser/…, ./render/…, new URL('images/', import.meta.url)), so the
  # sibling files must sit next to it. Nest under one subdir so buildEnv (which
  # flattens every customLovelaceModule into a single served directory) can't
  # collide our parser/render/images with another card's.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/idf-mobilite
    cp -vr dist/. $out/idf-mobilite/

    runHook postInstall
  '';

  passthru.entrypoint = "idf-mobilite/idf-mobilite.js";

  meta = {
    description = "Home Assistant Lovelace card for Île-de-France Mobilités (IDFM) real-time transit";
    homepage = "https://github.com/yyrkoon94/lovelace-idf-mobilite";
    license = lib.licenses.gpl3Only;
  };
}
