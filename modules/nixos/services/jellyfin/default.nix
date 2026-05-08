{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib.${namespace}) mkBoolOpt mkOpt;
  inherit (lib) mkEnableOption mkIf types;
  inherit (config.${namespace}.user) home;

  cfg = config.${namespace}.services.jellyfin;
  username = config.${namespace}.user.name;
in
{

  options.${namespace}.services.jellyfin = {
    enable = mkEnableOption "Whether or not to configure jellyfin.";
    base-url = mkOpt types.str "jf.daftdaf.dev" "The base url";
    port = mkOpt types.int 8096 "The port";
  };

  config = mkIf cfg.enable {

    users.groups.yahrr.members = [ "jellyfin" ];
    services.jellyfin = {
      enable = true;
      user = username;
      openFirewall = true;
      cacheDir = "${home}/.cache/jellyfin";
    };

    services.caddy.virtualHosts = {
      "${cfg.base-url}".extraConfig = ''
          reverse_proxy "http://0.0.0.0:${toString cfg.port}"
          import cloudflare
        '';
        "tv.daftdaf.dev".extraConfig = ''
          reverse_proxy "http://0.0.0.0:${toString cfg.port}"
          import cloudflare
        '';
        "video.daftdaf.dev".extraConfig = ''
          reverse_proxy "http://0.0.0.0:${toString cfg.port}"
          import cloudflare
        '';
    };
  };
}
