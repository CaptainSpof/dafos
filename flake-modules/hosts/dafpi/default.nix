# dafpi — Orange Pi 5 (RK3588S, 16 GB, NVMe): the always-on small server
# that takes load (and the LAN's second DNS) off dafoltop. First host built
# purely from flake-modules aspects; see ./AGENTS.md.
{ config, ... }:
let
  inherit (config.flake.modules) nixos homeManager;
in
{
  configurations.nixos.dafpi.module = {
    imports = with nixos; [
      avahi
      home
      locale
      networking
      nix
      openssh
      podman
      sops
      tailscale
      time
      user
    ];

    dafos = {
      nix.nh.enable = true;

      security.sops.enable = true;

      services = {
        avahi.enable = true;
        openssh.enable = true;
        tailscale.enable = true;
      };

      system = {
        locale.enable = true;
        networking.enable = true;
        time.enable = true;
      };

      virtualisation.podman.enable = true;

      # Legacy hosts get wheel implicitly from the vendored
      # snowfallorg.users module (admin = true); dendritic hosts must ask.
      # Moves into the user aspect when the compat layer goes (phase 3).
      user.extraGroups = [ "wheel" ];
    };

    home-manager.users.daf = {
      imports = [ homeManager.user ];

      dafos.user.enable = true;
    };

    # This value determines the NixOS release from which the default
    # settings for stateful data, like file locations and database versions
    # on your system were taken. Leave it at the release of the first install.
    system.stateVersion = "26.11";
  };
}
