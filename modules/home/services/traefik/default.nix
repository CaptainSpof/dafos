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
      geoblock.allowedCountries = [ "FR" ];

      dynamicConfig.http = {
        routers = {
          immich-nix = {
            # Listen for both domains
            rule = "Host(`immich.${cfg.base-url}`) || Host(`photos.${cfg.base-url}`)";
            service = "immich-service";
            entryPoints = [ "websecure" ];
            middlewares = [ "public@file" ];
            tls.certResolver = "letsencrypt"; # NPS default resolver name
          };
          home-assistant-nix = {
            rule = "Host(`home.${cfg.base-url}`)";
            service = "home-assistant-service";
            entryPoints = [ "websecure" ];
            middlewares = [ "public@file" ];
            tls.certResolver = "letsencrypt"; # NPS default resolver name
          };
          zone-configurator-nix = {
            rule = "Host(`zones.${cfg.base-url}`)";
            service = "zone-configurator-service";
            entryPoints = [ "websecure" ];
            # The zone configurator has no authentication of its own and can
            # rewrite sensor zones and push OTA firmware, so keep it on the
            # same source-IP gate as zigbee2mqtt.
            middlewares = [ "private@file" ];
            tls.certResolver = "letsencrypt"; # NPS default resolver name
          };
          zigbee2mqtt-nix = {
            rule = "Host(`z2m.${cfg.base-url}`)";
            service = "zigbee2mqtt-service";
            entryPoints = [ "websecure" ];
            # zigbee2mqtt has no authentication of its own and can pair/remove
            # devices on the mesh, so keep it source-IP gated. Traefik matches
            # routers on the Host header, not on the address the client dialled,
            # so a public DNS record pointing elsewhere is not a control here.
            middlewares = [ "private@file" ];
            tls.certResolver = "letsencrypt"; # NPS default resolver name
          };
        };

        middlewares = {
          # nps ships `private` as an RFC1918-only ipAllowList; the tailnet lives in
          # CGNAT space, so without this our own tailscale clients get a 403.
          ipwhitelist-internal.ipAllowList.sourceRange = lib.mkAfter [ "100.64.0.0/10" ];

          # Traefik was returning no content-encoding at all, even when the client
          # offered gzip/br: the glance dashboard shipped 72kB of JSON per page
          # load that gzips to 6kB. mkBefore puts this outermost so it wraps the
          # response from the rest of the chain.
          compress.compress = { };
          public.chain.middlewares = lib.mkBefore [ "compress" ];
        };

        services = {
          immich-service = {
            loadBalancer.servers = [
              {
                url = "http://host.containers.internal:2283";
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
          zone-configurator-service = {
            loadBalancer.servers = [
              {
                url = "http://host.containers.internal:42069";
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
