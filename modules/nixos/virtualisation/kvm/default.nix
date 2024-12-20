{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib)
    concatStringsSep
    getExe
    length
    mkIf
    optionalString
    types
    ;
  inherit (lib.${namespace}) mkBoolOpt enabled;
  inherit (config.${namespace}) user;

  cfg = config.${namespace}.virtualisation.kvm;
in
{
  options.${namespace}.virtualisation.kvm = with types; {
    enable = mkBoolOpt false "Whether or not to enable KVM virtualisation.";
    vfioIds = mkOpt (listOf str) [ ] "The hardware IDs to pass through to a virtual machine.";
    platform = mkOpt (enum [
      "amd"
      "intel"
    ]) "amd" "Which CPU platform the machine is using.";
    # Use `machinectl` and then `machinectl status <name>` to
    # get the unit "*.scope" of the virtual machine.
    machineUnits =
      mkOpt (listOf str) [ ]
        "The systemd *.scope units to wait for before starting Scream.";
  };

  config = mkIf cfg.enable {
    boot = {
      kernelModules = [
        "kvm-${cfg.platform}"
        "vfio_virqfd"
        "vfio_pci"
        "vfio_iommu_type1"
        "vfio"
      ];
      kernelParams = [
        "${cfg.platform}_iommu=on"
        "${cfg.platform}_iommu=pt"
        "kvm.ignore_msrs=1"
      ];
      extraModprobeConfig = optionalString (
        length cfg.vfioIds > 0
      ) "options vfio-pci ids=${concatStringsSep "," cfg.vfioIds}";
    };

    systemd.tmpfiles.rules = [
      "f /dev/shm/looking-glass 0660 ${user.name} qemu-libvirtd -"
      "f /dev/shm/scream 0660 ${user.name} qemu-libvirtd -"
    ];

    environment.systemPackages = with pkgs; [
      virt-manager

      # Needed for Windows 11
      swtpm
    ];

    virtualisation = {
      libvirtd = {
        enable = true;
        extraConfig = ''
          user="${user.name}"
        '';

        onBoot = "ignore";
        onShutdown = "shutdown";

        qemu = {
          package = pkgs.qemu_kvm;
          ovmf = enabled;
          verbatimConfig = ''
            namespaces = []
            user = "+${builtins.toString config.users.users.${user.name}.uid}"
          '';
        };
      };
    };

    dafos = {
      user = {
        extraGroups = [
          "qemu-libvirtd"
          "libvirtd"
          "disk"
        ];
      };

      apps = {
        looking-glass-client = enabled;
      };

      home = {
        extraOptions = {
          systemd.user.services.scream = {
            Unit = {
              Description = "Scream";
              After = [
                "libvirtd.service"
                "pipewire-pulse.service"
                "pipewire.service"
                "sound.target"
              ] ++ cfg.machineUnits;

            };
            Service = {
              ExecStart = "${getExe pkgs.scream} -n scream -o pulse -m /dev/shm/scream";
              Restart = "always";
              StartLimitIntervalSec = "5";
              StartLimitBurst = "1";
            };
            Install.RequiredBy = cfg.machineUnits;
          };
        };
      };
    };
  };
}
