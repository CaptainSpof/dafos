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

    # Upstream keeps CAP_SYS_NICE just long enough to start a high-priority EGL
    # context for capture/colour conversion. Without it a game pinning the GPU
    # starves the encoder: frames bunch up into oversized bursts and Moonlight
    # drops the stream. capSysAdmin alone only grants cap_sys_admin.
    security.wrappers.sunshine.capabilities = lib.mkForce "cap_sys_admin,cap_sys_nice+p";

    # Sunshine hangs in its portal capture init (no ports, no avahi) if the wlr
    # portal isn't up yet or crashes on first contact at login.
    systemd.user.services.sunshine = {
      after = [ "xdg-desktop-portal-wlr.service" ];
      wants = [ "xdg-desktop-portal-wlr.service" ];
    };
  };
}
