{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation rec {
  pname = "lovelace-auto-entities";
  version = "1.16.1";

  src = fetchFromGitHub {
    owner = "thomasloven";
    repo = "lovelace-auto-entities";
    rev = "refs/tags/v${version}";
    hash = "sha256-yMqf4LA/fBTIrrYwacUTb2fL758ZB1k471vdsHAiOj8=";
  };

  dontBuild = true;

  installPhase = ''

    mkdir $out
    cp -v auto-entities.js $out/

  '';

  passthru.entrypoint = "auto-entities.js";

  meta = {
    description = "🔹Automatically populate the entities-list of lovelace cards";
    homepage = "https://github.com/thomasloven/lovelace-auto-entities";
    license = lib.licenses.mit;
  };
}
