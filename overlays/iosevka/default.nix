# nodejs_26 26.9.0 ships a new test, parallel/test-fs-cp-async-file-modes, that
# chmods a file setuid. The Nix sandbox's seccomp filter always refuses that
# with EPERM, so nodejs-slim-26.9.0 fails its checkPhase on Hydra as well as
# locally and nothing built with it is cached. iosevka (and so iosevka-comfy,
# used by the fonts module) builds with `nodejs_latest`; build it with the
# cached LTS `nodejs` instead of compiling Node 26 from source.
# Drop this once nixpkgs skips that test and nodejs_26 is cached again.
_:

final: prev:

{
  iosevka = prev.iosevka.override {
    nodejs_latest = final.nodejs;
  };
}
