{
  lib,
  config,
  namespace,
  pkgs,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf;
  inherit (config.${namespace}.user) home;

  cfg = config.${namespace}.services.calibre;
  username = config.${namespace}.user.name;
in
{

  options.${namespace}.services.calibre = {
    enable = mkEnableOption "Whether or not to configure calibre.";
  };

  config = mkIf cfg.enable {

    dafos.user.extraGroups = [ "calibre" ];
    users.groups.yahrr.members = [ "calibre" ];

    users.users.calibre = {
      isSystemUser = true;
      group = "calibre";
      home = "/var/lib/calibre";
      createHome = false;
    };

    users.groups.calibre = {};

    services.calibre-server = {
      enable = true;
      user = "calibre";
      group = "yahrr";
      openFirewall = true;
      libraries = [
        "/mnt/livres"
      ];
      port = 8585;
      host = "0.0.0.0";
      package = pkgs.calibre;
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/calibre/ 0775 calibre calibre - -"
    ];
  };
}
