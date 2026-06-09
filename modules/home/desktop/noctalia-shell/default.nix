{
  config,
  lib,
  namespace,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;
  inherit (config.${namespace}.user) home;

  cfg = config.${namespace}.desktop.noctalia-shell;
in
{
  options.${namespace}.desktop.noctalia-shell = {
    enable = mkBoolOpt true "Whether or not to use noctalia-shell";
  };

  config = mkIf cfg.enable {
    # noctalia v5 renamed the home-manager option from `programs.noctalia-shell`
    # to `programs.noctalia` and switched the config format to TOML
    # (~/.config/noctalia/config.toml). See https://docs.noctalia.dev/v5
    programs.noctalia = {
      enable = true;
      systemd.enable = true;
      settings = {
        shell = {
          avatar_path = "${home}/.face";
          corner_radius_scale = 0.6;
          time_format = "{:%H:%M}";
          date_format = "%A %d %B";
          animation = {
            enabled = true;
            speed = 1.0;
          };
        };

        theme = {
          mode = "dark";
          source = "builtin";
          builtin = "Kanagawa";
        };

        bar.main = {
          position = "top";
          background_opacity = 0.0;
          capsule = true;
          reserve_space = true;
          margin_h = 0;
          margin_v = 0;
          start = [
            "control-center"
            "sysmon"
            "active_window"
            "media"
          ];
          center = [
            "clock"
          ];
          end = [
            "workspaces"
            "network"
            "caffeine"
            "tray"
            "notifications"
            "battery"
            "volume"
            "brightness"
            "session"
          ];
        };

        # Per-widget default settings.
        widget.clock = {
          format = "{:%A %d %B · %H:%M}";
        };

        dock = {
          enabled = true;
          auto_hide = true;
        };

        location = {
          auto_locate = false;
          address = "Paris, France";
        };

        wallpaper = {
          enabled = true;
          directory = "${home}/Pictures/wallpapers/";
          default = {
            path = "${home}/Pictures/wallpapers/annapurna.png";
          };
          automation = {
            enabled = true;
            interval_minutes = 3;
            order = "random";
            recursive = true;
          };
        };
      };
      # `settings` may also be a raw TOML string or a path to a .toml file,
      # but in that case it must include *all* settings.
    };
  };
}
