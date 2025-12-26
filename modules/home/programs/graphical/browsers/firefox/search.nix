{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.dafos) mkOpt;

  cfg = config.dafos.programs.graphical.browsers.firefox;
in
{
  options.dafos.programs.graphical.browsers.firefox = {
    search = mkOpt lib.types.attrs {
      default = "qwant";
      privateDefault = "qwant";
      # Home-manager skip collision check
      force = true;

      engines = {
        "Nix Issues" = {
          icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
          definedAliases = [
            "ni"
            "@ni"
          ];
          urls = [
            {
              template = "https://github.com/NixOS/nixpkgs/issues";
              params = [
                {
                  name = "q";
                  value = "{searchTerms}";
                }
              ];
            }
          ];
        };

        "Nix Packages" = {
          icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
          definedAliases = [
            "n"
            "@n"
          ];
          urls = [
            {
              template = "https://search.nixos.org/packages";
              params = [
                {
                  name = "type";
                  value = "packages";
                }
                {
                  name = "channel";
                  value = "unstable";
                }
                {
                  name = "query";
                  value = "{searchTerms}";
                }
              ];
            }
          ];
        };

        "NixOS Options" = {
          icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
          definedAliases = [
            "no"
            "@no"
          ];
          urls = [
            {
              template = "https://search.nixos.org/options";
              params = [
                {
                  name = "channel";
                  value = "unstable";
                }
                {
                  name = "query";
                  value = "{searchTerms}";
                }
              ];
            }
          ];
        };

        "GitHub" = {
          icon = "https://github.com/favicon.ico";
          updateInterval = 24 * 60 * 60 * 1000;
          definedAliases = [
            "gh"
            "@gh"
          ];

          urls = [
            {
              template = "https://github.com/search";
              params = [
                {
                  name = "q";
                  value = "{searchTerms}";
                }
              ];
            }
          ];
        };

        "Home Manager Options" = {
          icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
          definedAliases = [
            "hm"
            "@hm"
          ];
          urls = [
            {
              template = "https://home-manager-options.extranix.com";
              params = [
                {
                  name = "query";
                  value = "{searchTerms}";
                }
                {
                  name = "release";
                  value = "master";
                }
              ];
            }
          ];
        };
      };
    } "Search configuration";
  };

  config = lib.mkIf cfg.enable {
    programs.firefox.profiles.${config.dafos.user.name} = {
      inherit (cfg) search;
    };
  };
}
