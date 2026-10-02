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

  mkDate =
    { trigger, format }:
    {
      inherit trigger;
      replace = "{{d}}";
      vars = [
        {
          name = "d";
          type = "date";
          params = { inherit format; };
        }
      ];
    };
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
          backend = "auto";
          # Hot-reloaded workers stop expanding; the unit restarts on config change instead.
          auto_restart = false;
          inject_delay = 5;
          key_delay = 5;
        };
      };

      matches = {
        # Espanso regenerates its example base.yml when it is missing; own it, empty.
        base.matches = [ ];

        email = {
          matches = [
            {
              triggers = [
                "@me"
                "@daf"
              ];
              replace = email;
            }
            {
              trigger = "@cs";
              replace = gitEmail;
            }
          ];
        };

        date = {
          matches = map mkDate [
            {
              trigger = ":date:";
              format = "%d/%m/%Y";
            }
            {
              trigger = ":date-";
              format = "%d-%m-%Y";
            }
            {
              trigger = ":date_";
              format = "%Y-%m-%d";
            }
            {
              trigger = ":time:";
              format = "%H:%M";
            }
            {
              trigger = ":now:";
              format = "%d/%m/%Y %H:%M";
            }
            {
              trigger = ":isonow:";
              format = "%Y-%m-%dT%H:%M:%S%:z";
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

    # EVDEV worker needs the Wayland compositor (NoCompositor panic otherwise).
    systemd.user.services.espanso = {
      Unit = {
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
        # Full restart on config change: espanso's in-place worker reload leaves it not expanding.
        X-Restart-Triggers = [
          (builtins.toJSON {
            inherit (config.services.espanso) configs matches;
          })
        ];
      };
      Install.WantedBy = lib.mkForce [ "graphical-session.target" ];
    };
  };
}
