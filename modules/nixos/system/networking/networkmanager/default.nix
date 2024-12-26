{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib) mkIf;

  cfg = config.${namespace}.system.networking;
in
{
  config = mkIf cfg.enable {
    dafos.user.extraGroups = [ "networkmanager" ];

    networking = {
      wireless.iwd.enable = true;
      networkmanager = {
        enable = true;

        # wifi.backend = "iwd";
        # dhcp = "internal";

        connectionConfig = {
          "connection.mdns" = "2";
        };

        plugins = with pkgs; [
          networkmanager-l2tp
          networkmanager-openvpn
          networkmanager-sstp
          networkmanager-vpnc
        ];

        unmanaged =
          lib.optionals config.${namespace}.services.tailscale.enable [ "interface-name:tailscale*" ]
          ++ lib.optionals config.${namespace}.virtualisation.podman.enable [ "interface-name:docker*" ]
          ++ lib.optionals config.${namespace}.virtualisation.kvm.enable [ "interface-name:virbr*" ];
      };
    };

    systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;
  };
}
