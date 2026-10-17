# dafrelay — Raspberry Pi 4 B, installed off-site at a family member's home:
# the second copy of dafoltop's photos (restic rest-server on the USB dock)
# and, later, a fallback for immich-kiosk. Booted from a no-name 59 GB USB
# key, so the system writes as little as it can to it. See ./AGENTS.md.
{ config, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  configurations.nixos.dafrelay.module = {
    imports = with nixos; [
      avahi
      locale
      networking
      nix
      openssh
      raspberrypi4
      tailscale
      time
      user
    ];

    dafos = {
      nix.nh.enable = true;

      services = {
        avahi.enable = true;
        openssh.enable = true;
        # Joined by hand on first boot (`sudo tailscale up`): the auth key
        # needs sops, which needs this host's key first (README step 4).
        tailscale.enable = true;
      };

      system = {
        locale.enable = true;
        networking.enable = true;
        time.enable = true;
      };

      # Dendritic hosts must ask for wheel (see dafpi).
      user.extraGroups = [ "wheel" ];
    };

    # Unknown LAN at the destination: plain DHCP on the one wired port.
    networking.useNetworkd = true;
    systemd.network.networks."10-lan" = {
      matchConfig.Name = "en* eth*";
      networkConfig.DHCP = "yes";
      linkConfig.RequiredForOnline = "routable";
    };

    # The USB key's endurance is unknown: keep routine writes off it. Bulk
    # data (the restic repository) goes to the dock disks only.
    fileSystems."/".options = [ "noatime" ];
    boot.tmp.useTmpfs = true;
    services.journald.settings.Journal.SystemMaxUse = "200M";
    zramSwap.enable = true;

    # This value determines the NixOS release from which the default
    # settings for stateful data, like file locations and database versions
    # on your system were taken. Leave it at the release of the first install.
    system.stateVersion = "26.11";
  };

  # The whole system as a disk image, written straight to the USB key.
  perSystem =
    { lib, system, ... }:
    {
      packages = lib.mkIf (system == "aarch64-linux") {
        dafrelay-image = config.flake.nixosConfigurations.dafrelay.config.system.build.sdImage;
      };
    };
}
