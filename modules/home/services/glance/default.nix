{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.services.glance;
  domain = config.${namespace}.services.traefik.base-url;

  # Services that run as NixOS services on dafoltop, not as nps containers, so
  # the docker-containers widgets never see them. A monitor widget gives them
  # the same status checkmark. The check goes to the port Traefik proxies to
  # (see the `*-nix` routers in ../traefik) rather than the public hostname,
  # so a green tick means the service is up, not merely that Traefik is.
  mkSite =
    {
      title,
      port,
      icon,
      subDomain ? null,
    }:
    let
      internal = "http://host.containers.internal:${toString port}";
    in
    {
      inherit title icon;
      # Status-only services have no public route. Their link only resolves
      # from inside the glance container.
      url = if subDomain != null then "https://${subDomain}.${domain}" else internal;
      check-url = internal;
    };
in
{

  options.${namespace}.services.glance = {
    enable = mkEnableOption "Whether or not to configure glance.";
    subDomain = mkOpt types.str "fp" "The base url";
  };

  config = mkIf cfg.enable {
    nps.stacks = {
      glance = {
        enable = true;

        containers = {
          glance = {
            expose = true;
            traefik.subDomain = cfg.subDomain;

            # Glance ships no authentication of its own, and this dashboard
            # publishes dafoltop's server stats plus a bookmark map of the
            # internal services. Everything else on the public chain
            # authenticates somehow -- OIDC against Authelia, or the app's own
            # login -- so gate this one on Authelia too. `default_policy` is
            # `one_factor`, so no per-app rule or client secret is needed.
            forwardAuth.enable = true;
          };
        };

        settings.pages.home = {
          columns.left = {
            rank = 500;
            size = "small";
            widgets = [
              {
                type = "server-stats";
                servers = [
                  {
                    type = "local";
                    name = "Server";
                  }
                ];
              }
              {
                type = "reddit";
                subreddit = "selfhosted";
                collapse-after = 3;
                # Reddit resets glance's connections when it refreshes its loid
                # cookie, and the refresh is synchronous, so whichever page load
                # hits an expired cache stalls for ~1s. Default TTL made that
                # roughly every 40 minutes.
                cache = "6h";
              }
              {
                type = "monitor";
                title = "Backends";
                style = "compact";
                cache = "1m";
                sites = map mkSite [
                  {
                    # Home Assistant's notification text comes from here.
                    title = "Ollama";
                    port = 11434;
                    icon = "di:ollama";
                  }
                  {
                    title = "Blocky";
                    port = 4000;
                    icon = "di:blocky";
                  }
                ];
              }
            ];
          };
          columns.center = {
            rank = 1000;
            size = "full";
            # mkBefore keeps these above the docker-containers widgets that nps
            # appends per category.
            widgets = lib.mkBefore [
              {
                type = "monitor";
                title = "Host services";
                cache = "1m";
                sites = map mkSite [
                  {
                    title = "Home Assistant";
                    subDomain = "home";
                    port = 8123;
                    icon = "di:home-assistant";
                  }
                  {
                    title = "Immich";
                    subDomain = "immich";
                    port = 2283;
                    icon = "di:immich";
                  }
                  {
                    title = "Zigbee2MQTT";
                    subDomain = "z2m";
                    port = 8090;
                    icon = "di:zigbee2mqtt";
                  }
                  {
                    title = "Zone Configurator";
                    subDomain = "zones";
                    port = 42069;
                    icon = "mdi:radar";
                  }
                ];
              }
            ];
          };
          columns.right = {
            rank = 1500;
            size = "small";
            widgets = [
              {
                type = "calendar";
                first-day-of-week = "monday";
              }
              {
                type = "weather";
                location = "Nanterre, France";
              }
              {
                type = "search";
                search-engine = "google";
                new-tab = false;
              }
            ];
          };
        };
      };
    };
  };
}
