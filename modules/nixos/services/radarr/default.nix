{
  lib,
  config,
  namespace,
  ...
}:

let
  cfg = config.${namespace}.services.radarr;

  inherit (lib.${namespace}) mkOpt;
  inherit (lib) types mkEnableOption mkIf;
in
{
  options.${namespace}.services.radarr = {
    enable = mkEnableOption "Whether or not to configure radarr.";
    dataDir = mkOpt types.str "/var/lib/radarr" "The directory where Readarr stores its data files.";
  };

  config = mkIf cfg.enable {
    dafos.user.extraGroups = [ "radarr" ];
    services.radarr = {
      enable = true;
      # port = 7878; # For reference
      openFirewall = true;
    };
  };
}
