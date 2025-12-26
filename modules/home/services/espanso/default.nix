{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;
  inherit (config.${namespace}.user) email gitEmail fullName;

  cfg = config.${namespace}.services.espanso;
in
{
  options.${namespace}.services.espanso = {
    enable = mkBoolOpt false "Whether or not to enable espanso.";
  };

  config = mkIf cfg.enable {
    services.espanso = {
      enable = true;
      package = pkgs.espanso-wayland;
      waylandSupport = true;

      configs = {
        default = {
          search_shortcut = "ALT+SHIFT+SPACE";
          keyboard_layout = {
            layout = "fr";
            variant = "ergol";
          };
          backend = "inject";
          inject_delay = 5;
          key_delay = 5;
        };
      };

      matches = {
        email = {
          matches = [
            {
              trigger = "@me";
              replace = email;
            }
            {
              trigger = "@cs";
              replace = gitEmail;
            }
          ];
        };
        date = {
          matches = [
            {
              trigger = ":date:";
              replace = "{{mydate}}";
              vars = [
                {
                  name = "mydate";
                  type = "date";
                  params = {
                    format = "%x";
                    locale = "fr-FR";
                  };
                }
              ];
            }
          ];
        };
        misc = {
          matches = [
            {
              triggers = [
                ":me:"
                ":daf:"
              ];
              replace = fullName;
            }
          ];
        };
        templates = {
          matches = [
            {
              trigger = ":tick:";
              replace = ''
                $|$
                ---
                **Refs:**
                -
              '';
            }
          ];
        };
        symbols = {
          backend = "inject";
          inject_delay = 15;
          key_delay = 15;
          matches = [
            {
              trigger = ":ar:";
              replace = "→";
            }
            {
              trigger = ":al:";
              replace = "←";
            }
          ];
        };
      };
    };
  };
}
