{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.services.immich-kiosk;
in
{

  options.${namespace}.services.immich-kiosk = {
    enable = mkEnableOption "Whether or not to configure immich-kiosk.";
    subDomain = mkOpt types.str "kiosk" "The subdomain immich-kiosk is served on";
  };

  config = mkIf cfg.enable {
    sops.secrets = {
      "immich-kiosk-api-key-env".sopsFile = lib.snowfall.fs.get-file "secrets/daf/immich-kiosk.yaml";
      "immich-kiosk-albums-key-env".sopsFile = lib.snowfall.fs.get-file "secrets/daf/immich-kiosk.yaml";
      "immich-kiosk-weather-api-key-env".sopsFile =
        lib.snowfall.fs.get-file "secrets/daf/immich-kiosk.yaml";
    };

    nps.stacks.immich-kiosk = {
      enable = true;

      # KIOSK_IMMICH_API_KEY / KIOSK_ALBUMS (env-formatted sops secrets)
      environmentFiles = [
        config.sops.secrets."immich-kiosk-api-key-env".path
        config.sops.secrets."immich-kiosk-albums-key-env".path
      ];
      weatherApiKeyFile = config.sops.secrets."immich-kiosk-weather-api-key-env".path;

      containers.immich-kiosk = {
        expose = true;
        traefik = {
          inherit (cfg) subDomain;
          middleware.authelia.enable = true;
        };
        environment = {
          LANG = "fr_FR";
          TZ = "Europe/Paris";
        };
      };

      customCss = builtins.readFile ./custom.css;

      settings = import ./settings.nix;
    };
  };
}
