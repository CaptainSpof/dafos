# SD-card installer for dafpi: boots the Orange Pi 5 with U-Boot embedded
# in the image (the SPI flash may still be empty), offers SSH as root with
# daf's keys, and carries the tools to flash U-Boot to SPI and install
# onto the NVMe. Build: nix build .#packages.aarch64-linux.dafpi-installer
{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;

  installer = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      nixos.orangepi5
      nixos.user
      (
        {
          config,
          modulesPath,
          pkgs,
          ...
        }:
        let
          uboot = pkgs.ubootOrangePi5;
        in
        {
          imports = [
            (modulesPath + "/installer/sd-card/sd-image.nix")
            (modulesPath + "/profiles/base.nix")
          ];

          networking.hostName = "dafpi-installer";

          sdImage = {
            imageBaseName = "dafpi-installer";
            compressImage = false;

            # u-boot-rockchip.bin = idbloader at 32 KiB + u-boot.itb at 8 MiB;
            # keep the (unused) firmware partition clear of it.
            firmwarePartitionOffset = 16;
            firmwareSize = 16;
            populateFirmwareCommands = "";

            populateRootCommands = ''
              mkdir -p ./files/boot
              ${config.boot.loader.generic-extlinux-compatible.populateCmd} \
                -c ${config.system.build.toplevel} -d ./files/boot
            '';

            postBuildCommands = ''
              dd if=${uboot}/u-boot-rockchip.bin of=$img seek=64 conv=notrunc
            '';
          };

          # The SPI image for the first boot: see README.md, step "flash SPI".
          environment.etc."dafpi/u-boot-rockchip-spi.bin".source = "${uboot}/u-boot-rockchip-spi.bin";

          environment.systemPackages = with pkgs; [
            mtdutils
            nvme-cli
            pciutils
          ];

          boot.kernelModules = [ "spi_rockchip_sfc" ];

          services.openssh = {
            enable = true;
            settings.PermitRootLogin = "prohibit-password";
          };
          users.users.root.openssh.authorizedKeys.keys = config.dafos.user.authorizedKeys;

          networking.useNetworkd = true;
          systemd.network.networks."10-lan" = {
            matchConfig.Name = "en* eth*";
            networkConfig.DHCP = "yes";
          };

          nix.settings.experimental-features = [
            "nix-command"
            "flakes"
          ];

          system.stateVersion = "26.11";
        }
      )
    ];
  };
in
{
  perSystem =
    { lib, system, ... }:
    {
      packages = lib.mkIf (system == "aarch64-linux") {
        dafpi-installer = installer.config.system.build.sdImage;
      };
    };
}
