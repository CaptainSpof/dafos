{
  config,
  lib,
  namespace,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.desktop.dankcalendar;

  dmsCfg = config.programs.dank-material-shell;
in
{
  options.${namespace}.desktop.dankcalendar = {
    enable = mkBoolOpt false "Whether or not to run DankCalendar (dcal) — the standalone Google/Microsoft/CalDAV/iCloud calendar daemon backing DMS's `dankcal` calendar backend.";
  };

  config = mkIf cfg.enable {
    programs.dank-calendar = {
      enable = true;

      # dcal launches its embedded QML UI with `qs`. DMS already installs a
      # quickshell wrapped with QtWebSockets into home.packages; installing
      # plain pkgs.quickshell alongside it would collide on bin/qs, so reuse
      # whatever quickshell DMS settled on when DMS is enabled.
      quickshell.package = lib.mkIf dmsCfg.enable dmsCfg.quickshell.package;

      systemd = {
        enable = true; # dcal.service, started with the wayland session
        restartIfChanged = true;
      };

      # Deliberately left empty: programs.dank-calendar.settings writes
      # ~/.config/dankcal/ui-settings.json as a read-only store symlink, and
      # dcal's SettingsData rewrites that file whenever a setting is changed in
      # the app (same EACCES trap as DMS's settings.json — see ../dms). The
      # upstream defaults already match the fleet (24h clock, locale-derived
      # first day of week, reminders on), so let dcal own the file.
      settings = { };
    };
  };
}
