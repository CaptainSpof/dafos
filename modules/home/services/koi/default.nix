{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib) mkIf getExe';
  inherit (lib.${namespace}) mkBoolOpt;
  inherit (config.${namespace}.user.location) latitude longitude;

  cfg = config.${namespace}.services.koi;
in
{
  options.${namespace}.services.koi = {
    enable = mkBoolOpt false "Whether or not to enable koi.";
  };

  config = mkIf cfg.enable {
    home.packages = [
      pkgs.kdePackages.koi
    ];

    systemd.user.services.koi = {
      Unit = {
        Description = "koi";
        # koi is a Plasma color-scheme switcher; bind it to the Plasma
        # session only.
        After = [ "plasma-workspace.target" ];
        PartOf = [ "plasma-workspace.target" ];
      };

      Install = {
        WantedBy = [ "plasma-workspace.target" ];
      };

      Service = {
        ExecStart = "${getExe' pkgs.kdePackages.koi "koi"}";
        Restart = "on-failure";
      };
    };

    # Under niri, DMS renders ~/.config/gtk-{3,4}.0/gtk.css from matugen so GTK
    # apps follow the wallpaper. That file is shared across sessions, so on a
    # Plasma login the leftover matugen @define-color block would override the
    # Gruvbox theme koi sets (especially for gtk4/libadwaita apps, which read
    # gtk.css directly). Truncate both files when the Plasma session starts so
    # koi's theme wins. DMS re-renders them on the next niri login.
    systemd.user.services.koi-neutralise-gtk-css = {
      Unit = {
        Description = "Blank matugen GTK css under Plasma so koi's theme applies";
        Before = [ "koi.service" ];
        PartOf = [ "plasma-workspace.target" ];
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${lib.getExe pkgs.bash} -c 'mkdir -p \"$HOME/.config/gtk-3.0\" \"$HOME/.config/gtk-4.0\"; : > \"$HOME/.config/gtk-3.0/gtk.css\"; : > \"$HOME/.config/gtk-4.0/gtk.css\"'";
      };
      Install = {
        WantedBy = [ "plasma-workspace.target" ];
      };
    };

    # koi rewrites the GTK theme files at runtime (~/.gtkrc-2.0 and the gtk-3.0
    # settings.ini) to switch light/dark, turning the home-manager-managed
    # symlinks into plain files. On the next activation HM tries to back them up
    # to *.hm.old; once a backup already exists it refuses to clobber it and the
    # whole activation aborts ("would be clobbered by backing up"). Drop the live
    # files and any stale backup before HM links, so there is nothing to back up.
    # koi regenerates them on the next theme change.
    home.activation.dropKoiGtkFiles = config.lib.dag.entryBefore [ "checkLinkTargets" ] ''
      run rm -f \
        "$HOME/.gtkrc-2.0" "$HOME/.gtkrc-2.0.hm.old" \
        "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini.hm.old"
    '';

    xdg.configFile."koirc".text = lib.generators.toINI { } {
      General = {
        notify = 2;
        schedule = 2;
        schedule-type = "sun";
        inherit latitude longitude;
        start-hidden = 2;
      };
      ColorScheme = {
        enabled = true;
        dark = "${pkgs.kde-gruvbox}/share/color-schemes/Gruvbox.colors";
        light = "${pkgs.dafos.kde-warm-eyes}/share/color-schemes/WarmEyes.colors";
      };
      GTKTheme = {
        enabled = true;
        dark = "Gruvbox-Dark";
        light = "Gruvbox-Light";
      };
      IconTheme = {
        enabled = false;
        dark = "Papirus-Dark";
        light = "Papirus";
      };
    };
  };
}
