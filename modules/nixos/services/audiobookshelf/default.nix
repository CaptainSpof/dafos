{
  lib,
  config,
  namespace,
  ...
}:

let
  cfg = config.${namespace}.services.audiobookshelf;

  inherit (lib.${namespace}) mkBoolOpt mkOpt;
  inherit (lib) mkEnableOption mkIf types;
in
  {
    options.${namespace}.services.audiobookshelf = {
      enable = mkEnableOption "Whether or not to configure audiobookshelf.";
      base-url = mkOpt types.str "audiobook.daftdaf.dev" "The base url";
      port = mkOpt types.int 8010 "The port";
    };

    config = mkIf cfg.enable {
      users.groups.yahrr.members = [ "audiobookshelf" ];


      services.audiobookshelf = {
        enable = true;
        openFirewall = true;
        inherit (cfg) port;
        host = "0.0.0.0";
      };

      fileSystems."/var/lib/audiobookshelf/metadata/tmp" = {
        device = "/mnt/audio/audiobookshelf/metadata/tmp";
        options = [ "bind" ];
      };

      systemd.tmpfiles.rules = [
        "d /mnt/audio/audiobookshelf/metadata/tmp 0750 audiobookshelf yahrr - -"
      ];

      services.caddy.virtualHosts = {
        "${cfg.base-url}".extraConfig = ''
          reverse_proxy "http://0.0.0.0:${toString cfg.port}"
          import cloudflare
        '';
      };
    };
  }
