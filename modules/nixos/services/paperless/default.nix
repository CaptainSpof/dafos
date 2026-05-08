{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib.${namespace}) mkBoolOpt mkOpt;
  inherit (lib) mkEnableOption mkIf types getExe;

  cfg = config.${namespace}.services.paperless;
in
{
  options.${namespace}.services.paperless = {
    enable = mkEnableOption "Whether or not to enable paperless";

    base-url = mkOpt types.str "paperless.daftdaf.dev" "The base url";
    port = mkOpt types.int 8050 "The port";
  };

  config = mkIf cfg.enable {
    services.paperless.enable = true;
    services.paperless.port = cfg.port;
    services.paperless.address = "0.0.0.0";
    services.paperless.domain = cfg.base-url;
    services.paperless.settings =
      {
        PAPERLESS_CONSUMER_IGNORE_PATTERN = [
          ".DS_STORE/*"
          "desktop.ini"
        ];
        PAPERLESS_OCR_LANGUAGE = "fra+eng";
        PAPERLESS_CSRF_TRUSTED_ORIGINS = "https://paperless.daftdaf.dev";
        PAPERLESS_URL = "https://paperless.daftdaf.dev";
        PAPERLESS_TRUSTED_PROXIES = "https://paperless.daftdaf.dev";
        PAPERLESS_ALLOWED_HOSTS = "https://paperless.daftdaf.dev";
        PAPERLESS_CORS_ALLOWED_HOSTS = "https://paperless.daftdaf.dev";
        PAPERLESS_OCR_USER_ARGS = {
          optimize = 1;
          pdfa_image_compression = "lossless";
        };
      };

    services.caddy.virtualHosts = {
      "${cfg.base-url}".extraConfig = ''
          reverse_proxy "http://0.0.0.0:${toString cfg.port}"
          import cloudflare
        '';
    };
  };
}
