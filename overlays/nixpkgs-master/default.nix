{ channels, ... }:

final: prev:

{
    inherit (channels.nixpkgs-master)
    ;


    # python313 = prev.python313.override {
    #   packageOverrides = _pyFinal: pyPrev: {
    #     psycopg = (channels.nixpkgs-master.python313Packages.psycopg.overrideAttrs (_old: {
    #       doCheck = false;
    #       pytestCheckPhase = "true"; # belt and suspenders
    #     }));
    #     pyrate-limiter = pyPrev.pyrate-limiter.overrideAttrs (_old: {
    #       doCheck = false;
    #     });
    #   };
    # };
    #   python313Packages = final.python313.pkgs;
}
