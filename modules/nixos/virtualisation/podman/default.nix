{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib) mkIf mkMerge;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.virtualisation.podman;
in
{
  options.${namespace}.virtualisation.podman = {
    enable = mkBoolOpt false "Whether or not to enable Podman.";
  };

  config = mkMerge [
    # Let containers reach aardvark-dns on the bridge gateway (port 53).
    # Without this, DNS lookups from containers on custom podman networks are
    # silently dropped by the host firewall (symptom: "dial tcp: lookup <host>
    # on 10.89.x.1:53: i/o timeout" inside containers). Keyed on the upstream
    # option because oci-container service modules auto-enable podman without
    # going through dafos.virtualisation.podman.
    (mkIf config.virtualisation.podman.enable {
      networking.firewall.interfaces."podman+" = {
        allowedUDPPorts = [ 53 ];
        allowedTCPPorts = [ 53 ];
      };
    })
    (mkIf cfg.enable {
      # NixOS 22.05 moved NixOS Containers to a new state directory and the old
      # directory is taken over by OCI Containers (eg. podman). For systems with
      # system.stateVersion < 22.05, it is not possible to have both enabled.
      # This option disables NixOS Containers, leaving OCI Containers available.
      boot.enableContainers = false;

      # Rootless podman needs a subordinate id range. Without /etc/subuid and
      # /etc/subgid the user namespace maps exactly one id (container 0 -> the
      # user), so every image file owned by anyone else is stored as 65534 and
      # crun fails with `fchownat: Invalid argument` as soon as a container has
      # to reproduce that ownership — which is what breaks minikube's kicbase,
      # whose /run is a tmpcopyup tmpfs holding a non-root /run/dbus/containers.
      users.users.${config.${namespace}.user.name}.autoSubUidGidRange = true;

      environment.systemPackages = with pkgs; [
        compose2nix
        podman-compose
        # podman-desktop
      ];

      dafos = {
        user = {
          extraGroups = [
            "docker"
            "podman"
          ];
        };

        home.extraOptions = {
          home.shellAliases = {
            "docker-compose" = "podman-compose";
          };
        };
      };

      virtualisation = {
        podman = {
          inherit (cfg) enable;

          # prune images and containers periodically
          autoPrune = {
            enable = true;
            flags = [ "--all" ];
            dates = "weekly";
          };

          dockerCompat = true;
          dockerSocket.enable = true;
        };
      };
    })
  ];
}
