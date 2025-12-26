{ channels, ... }:

_final: prev:

{
  kdePackages = prev.kdePackages // {
    # koi = prev.kdePackages.koi.overrideAttrs (oldAttrs: {

    #   # Update the source
    #   src = prev.fetchFromGitHub {
    #     owner = "baduhai";
    #     repo = "Koi";
    #     rev = "0.5";
    #     sha256 = "sha256-prkxFZW1F/I5jOOV5fZryHCYBSWAlGwH5afNEjKd2Ek=";
    #   };
    # });
  };
}
