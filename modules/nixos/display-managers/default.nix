{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib) mkIf types;
  inherit (lib.${namespace}) mkOpt mkBoolOpt;

  cfg = config.${namespace}.display-managers;
in
{
  options.${namespace}.display-managers = with types; {
    enable = mkBoolOpt false "Whether or not to enable sddm.";
    autoLogin.enable = mkBoolOpt false "Whether or not to enable autoLogin";
    autoLogin.user = mkOpt str "" "The user to auto login with.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs.kdePackages; [
      sddm
    ];

    services = {
      displayManager = {
        autoLogin = {
          inherit (cfg.autoLogin) enable user;
        };
      };
    };
  };
}
