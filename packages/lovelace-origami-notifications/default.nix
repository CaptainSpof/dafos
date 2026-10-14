{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation rec {
  pname = "lovelace-origami-notifications";
  version = "1.4.1";

  src = fetchFromGitHub {
    owner = "hazymorning";
    repo = "origami_notifications";
    rev = "v${version}";
    hash = "sha256-T+YexlqyMYXiIxjLLFLkBEqDDOeLfsxM0br0vUKJNkM=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm644 dist/origami-notifications.js $out/origami-notifications.js

    runHook postInstall
  '';

  passthru.entrypoint = "origami-notifications.js";

  meta = {
    description = "Rotating notifications card for the Origami Home Assistant dashboard";
    homepage = "https://github.com/hazymorning/origami_notifications";
    license = lib.licenses.mit;
  };
}
