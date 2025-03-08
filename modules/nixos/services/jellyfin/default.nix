{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf;
  inherit (config.${namespace}.user) home;

  cfg = config.${namespace}.services.jellyfin;
  username = config.${namespace}.user.name;
in
{

  options.${namespace}.services.jellyfin = {
    enable = mkEnableOption "Whether or not to configure jellyfin.";
  };

  config = mkIf cfg.enable {

    users.groups.yahrr.members = [ "jellyfin" ];
    services.jellyfin = {
      enable = true;
      user = username;
      openFirewall = true;
      cacheDir = "${home}/.cache/jellyfin";
    };
  };
}
