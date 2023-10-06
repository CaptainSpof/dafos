{ lib, config, ... }:

let
  inherit (lib) types mkIf mkDefault mkMerge;
  inherit (lib.dafos) mkOpt;

  cfg = config.dafos.user;

  home-directory =
    if cfg.name == null then
      null
    else
      "/home/${cfg.name}";
in
{
  options.dafos.user = {
    enable = mkOpt types.bool false "Whether to configure the user account.";
    name = mkOpt (types.nullOr types.str) config.snowfallorg.user.name "The user account.";

    fullName = mkOpt types.str "Cédric Da Fonseca" "The full name of the user.";
    email = mkOpt types.str "dafonseca.cedric@gmail.com" "The email of the user.";

    home = mkOpt (types.nullOr types.str) home-directory "The user's home directory.";
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = cfg.name != null;
          message = "dafos.user.name must be set";
        }
        {
          assertion = cfg.home != null;
          message = "dafos.user.home must be set";
        }
      ];

      home = {
        username = mkDefault cfg.name;
        homeDirectory = mkDefault cfg.home;
      };
    }
  ]);
}
