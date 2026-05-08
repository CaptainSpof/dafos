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
                }
              ];
            };
            columns.center = {
              rank = 1000;
              size = "full";
              widgets = [
                {
                  type = "bookmarks";
                  groups =
                    [
                      {
                        title = "General";
                        links = [
                          {
                            title = "Home-Assistant";
                            url = "https://home.daftdaf.dev";
                            icon = "di:home-assistant";
                          }
                          {
                            title = "Immich";
                            url = "https://immich.daftdaf.dev";
                            icon = "di:immich";
                          }
                        ];
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
