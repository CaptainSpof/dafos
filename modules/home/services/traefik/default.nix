{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.services.traefik;
in
  {

    options.${namespace}.services.traefik = {
      enable = mkEnableOption "Whether or not to configure traefik.";
      base-url = mkOpt types.str "daftdaf.dev" "The base url";
    };

    config = mkIf cfg.enable {
      sops.secrets."cloudflare-api-token" = {
        sopsFile = lib.snowfall.fs.get-file "secrets/daf/cloudflare.yaml";
      };

      nps.stacks.traefik = {
        enable = true;
        domain = cfg.base-url;
        geoblock.allowedCountries = ["FR"];

        dynamicConfig.http = {
          routers = {
            immich-nix = {
              # Listen for both domains
              rule = "Host(`immich.${cfg.base-url}`) || Host(`photos.${cfg.base-url}`)";
              service = "immich-service";
              entryPoints = [ "websecure" ];
              tls.certResolver = "letsencrypt"; # NPS default resolver name
            };
            immich-kiosk-nix = {
              rule = "Host(`kiosk.${cfg.base-url}`)";
              service = "immich-kiosk-service";
              entryPoints = [ "websecure" ];
              tls.certResolver = "letsencrypt"; # NPS default resolver name
            };
            home-assistant-nix = {
              rule = "Host(`home.${cfg.base-url}`)";
              service = "home-assistant-service";
              entryPoints = [ "websecure" ];
              tls.certResolver = "letsencrypt"; # NPS default resolver name
            };
            zigbee2mqtt-nix = {
              rule = "Host(`z2m.${cfg.base-url}`)";
              service = "zigbee2mqtt-service";
              entryPoints = [ "websecure" ];
              tls.certResolver = "letsencrypt"; # NPS default resolver name
            };
          };
          services = {
            immich-service = {
              loadBalancer.servers = [
                {
                  url = "http://host.containers.internal:2283";
                }
              ];
            };
            immich-kiosk-service = {
              loadBalancer.servers = [
                {
                  url = "http://host.containers.internal:8085";
                }
              ];
            };
            home-assistant-service = {
              loadBalancer.servers = [
                {
                  url = "http://host.containers.internal:8123";
                }
              ];
            };
            zigbee2mqtt-service = {
              loadBalancer.servers = [
                {
                  url = "http://host.containers.internal:8090";
                }
              ];
            };
          };
        };

        containers.traefik.extraConfig.Container.DNS = "1.1.1.1";

        extraEnv = {
          CF_DNS_API_TOKEN.fromFile = config.sops.secrets."cloudflare-api-token".path;
        };
      };
    };
  }
