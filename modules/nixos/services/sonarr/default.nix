{
  lib,
  config,
  namespace,
  ...
}:

let
  cfg = config.${namespace}.services.sonarr;

  username = config.${namespace}.user.name;
  inherit (lib) mkEnableOption mkIf;
in
{
  options.${namespace}.services.sonarr = {
    enable = mkEnableOption "Whether or not to configure sonarr.";
  };

  config = mkIf cfg.enable {
    users.groups.yahrr.members = [ "sonarr" ];
    services.sonarr = {
      enable = true;
      user = username;
      openFirewall = true;
    };
  };
}
