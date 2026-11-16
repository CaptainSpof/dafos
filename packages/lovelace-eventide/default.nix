{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation rec {
  pname = "lovelace-eventide";
  version = "1.1.0";

  # The release ships the built bundle; the repo itself needs bun to build.
  src = fetchurl {
    url = "https://github.com/kriakiku/eventide-card/releases/download/v${version}/eventide-card.js";
    hash = "sha256-H2F+oVXl5EGkspxyyY1Q0G5vRhaq6DGOWlJX1CftdMs=";
  };

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm644 $src $out/eventide-card.js

    runHook postInstall
  '';

  passthru.entrypoint = "eventide-card.js";

  meta = {
    description = "Calendar card for Home Assistant where events rise before they start and ebb while they run";
    homepage = "https://github.com/kriakiku/eventide-card";
    license = lib.licenses.mit;
  };
}
