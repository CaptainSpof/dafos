{
  config,
  lib,
  namespace,
  ...
}:

let
  inherit (lib) mkIf mkForce;

  cfg = config.${namespace}.system.networking;
in
{
  config = mkIf (cfg.enable && cfg.dns == "systemd-resolved") {
    networking.networkmanager.dns = "systemd-resolved";
    services.dnsmasq.enable = mkForce false;
    services.resolved = {
      enable = true;

      dnssec = "true";
      # this is necessary to get tailscale picking up your headscale instance
      # and allows you to ping connected hosts by hostname
      domains = [ "~." ];
      dnsovertls = "true";

      extraConfig = lib.mkIf config.services.avahi.enable ''
        MulticastDNS=no
      '';

      fallbackDns = [
        "8.8.8.8"
        "1.1.1.1"
        "100.100.100.100"
      ];
    };

    # environment.etc = {
    #   "systemd/resolved.conf".text = ''
    #     [Resolve]
    #     DNS=100.122.98.115
    #     Domains=~plop

    #     DNS=100.70.68.47:8123  # HASS
    #     Domains=hass.plop
    #   '';
    # };
  };
}
