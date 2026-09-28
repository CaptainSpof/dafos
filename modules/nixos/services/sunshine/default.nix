{
  lib,
  config,
  namespace,
  ...
}:

let
  cfg = config.${namespace}.services.sunshine;
  inherit (lib) mkEnableOption mkIf;
in
{
  options.${namespace}.services.sunshine = {
    enable = mkEnableOption "Whether or not to configure sunshine.";
  };

  config = mkIf cfg.enable {
    services.sunshine = {
      enable = true;
      autoStart = true;
      capSysAdmin = true;
      openFirewall = true;
    };

    # Sunshine hangs in its portal capture init (no ports, no avahi) if the wlr
    # portal isn't up yet or crashes on first contact at login.
    systemd.user.services.sunshine = {
      after = [ "xdg-desktop-portal-wlr.service" ];
      wants = [ "xdg-desktop-portal-wlr.service" ];
    };
  };
}
