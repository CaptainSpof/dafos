# nixpkgs' authelia-web pnpmDeps hash (4.39.28) does not match what the
# fetcher produces here: hash mismatch on dafoltop. Drop this once nixpkgs
# ships a hash that builds.
_:

_final: prev:

let
  web = prev.callPackage "${prev.path}/pkgs/by-name/au/authelia/web.nix" { };
in
{
  authelia = prev.authelia.override {
    authelia-web = web.overrideAttrs (old: {
      pnpmDeps = old.pnpmDeps.overrideAttrs (_: {
        outputHash = "sha256-zIaVEjbh/LIQMqnryrgVm+46GP+9gM91WCMyAqeDnaA=";
      });
    });
  };
}
