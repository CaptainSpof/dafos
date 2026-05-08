{
  lib,
  config,
  namespace,
  ...
}:

let
  cfg = config.${namespace}.services.glance;

  inherit (lib) mkEnableOption mkIf;
in
{
  options.${namespace}.services.glance = {
    enable = mkEnableOption "Whether or not to configure glance.";
  };

  config = mkIf cfg.enable {
    services.glance = {
      enable = true;
      openFirewall = true;
      settings = {
        server = {
          port = 8181;
          host = "0.0.0.0";
        };
        pages = [
          {
            name = "Home";
            columns = [
              {
                size = "small";
                widgets = [
                  { type = "calendar"; }
                  {
                    type = "rss";
                    limit = 10;
                    collapse-after = 3;
                    cache = "3h";
                    feeds = [
                      { url = "https://ciechanow.ski/atom.xml"; }
                      {
                        url = "https://www.joshwcomeau.com/rss.xml";
                        title = "Josh Comeau";
                      }
                      { url = "https://samwho.dev/rss.xml"; }
                      { url = "https://awesomekling.github.io/feed.xml"; }
                      {
                        url = "https://ishadeed.com/feed.xml";
                        title = "Ahmad Shadeed";
                      }
                    ];
                  }
                  {
                    type = "twitch-channels";
                    channels = [
                      "m4fgaming"
                      "cohhcarnage"
                      "furgoth"
                      "robbaz"
                      "pressea"
                    ];
                  }
                ];
              }
              {
                size = "full";
                widgets = [
                  {
                    type = "search";
                    autofocus = true;
                    search-engine = "google";
                    bangs = [
                      {
                        title = "YouTube";
                        shortcut = "!yt";
                        url = "https://www.youtube.com/results?search_query={QUERY}";
                      }
                    ];
                  }
                  { type = "hacker-news"; }
                  {
                    type = "videos";
                    channels = [
                      "UCR-DXc1voovS8nhAvccRZhg"
                      "UCv6J_jJa8GJqFwQNgNrMuww"
                      "UCOk-gHyjcWZNj3Br4oxwh0A"
                    ];
                  }
                  {
                    type = "reddit";
                    subreddit = "selfhosted";
                  }
                ];
              }
              {
                size = "small";
                widgets = [
                  {
                    type = "weather";
                    location = "Nanterre, France";
                  }
                ];
              }
            ];
          }
        ];
      };
    };
  };
}
