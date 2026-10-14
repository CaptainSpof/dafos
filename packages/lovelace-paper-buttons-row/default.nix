{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation rec {
  pname = "lovelace-paper-buttons-row";
  version = "2.3.1";

  # The repo only has TypeScript sources; the built bundle is a release asset.
  src = fetchurl {
    url = "https://github.com/jcwillox/lovelace-paper-buttons-row/releases/download/v${version}/paper-buttons-row.js";
    hash = "sha256-9pBUFEdzmrrzmMU7SWE3e+g1GefSojiQsVudaNmhr7w=";
  };

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm644 $src $out/paper-buttons-row.js

    runHook postInstall
  '';

  passthru.entrypoint = "paper-buttons-row.js";

  meta = {
    description = "Adds highly configurable buttons that use actions and per-state styling";
    homepage = "https://github.com/jcwillox/lovelace-paper-buttons-row";
    license = lib.licenses.mit;
  };
}
