{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.services.printing;
in
{
  options.${namespace}.services.printing = {
    enable = mkBoolOpt false "Whether or not to configure printing support.";
  };

  config = mkIf cfg.enable {
    services.printing = {
      enable = true;
      browsing = true;

      drivers = [
        pkgs.cnijfilter2
      ];
    };

    environment.systemPackages = with pkgs.kdePackages; [ skanpage ];
  };
}
