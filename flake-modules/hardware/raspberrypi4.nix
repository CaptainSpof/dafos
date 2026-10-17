# Raspberry Pi 4 B on mainline: nixpkgs' default kernel carries the board's
# device tree and drivers. The EEPROM bootloader reads the FAT firmware
# partition (Pi firmware + U-Boot), U-Boot boots the extlinux entries on
# the root partition. The disk layout is nixpkgs' SD image (also written to
# USB disks): FIRMWARE + NIXOS_SD, grown to the whole disk on first boot.
# See flake-modules/hosts/dafrelay/README.md.
{
  flake.modules.nixos.raspberrypi4 =
    {
      config,
      modulesPath,
      pkgs,
      ...
    }:
    let
      configTxt = pkgs.writeText "config.txt" ''
        [pi4]
        kernel=u-boot.bin
        arm_64bit=1
        enable_gic=1
        armstub=armstub8-gic.bin
        # U-Boot needs it, whether the UART is wired or not.
        enable_uart=1
        # Keeps the firmware from drawing over the kernel's framebuffer.
        avoid_warnings=1
        disable_overscan=1
        arm_boost=1
      '';
      fw = "${pkgs.raspberrypifw}/share/raspberrypi/boot";
    in
    {
      # sd-image.nix alone: the sd-image-aarch64 wrapper pulls in the
      # installer's base profile (ZFS, recovery tools) and every Pi's files.
      imports = [ (modulesPath + "/installer/sd-card/sd-image.nix") ];

      nixpkgs.hostPlatform = "aarch64-linux";

      boot = {
        loader = {
          grub.enable = false;
          generic-extlinux-compatible.enable = true;
        };

        # Root on USB: the VL805 xHCI sits behind the PCIe bridge and needs
        # its firmware reset from the VideoCore before it enumerates.
        initrd.availableKernelModules = [
          "pcie_brcmstb"
          "reset-raspberrypi"
          "xhci_pci"
          "usb_storage"
          "uas"
        ];

        kernelParams = [ "console=tty1" ];
      };

      hardware.deviceTree.name = "broadcom/bcm2711-rpi-4-b.dtb";

      sdImage = {
        compressImage = false;
        populateFirmwareCommands = ''
          (cd ${fw} && cp bootcode.bin fixup*.dat start*.elf bcm2711-rpi-4-b.dtb $NIX_BUILD_TOP/firmware/)
          cp ${pkgs.raspberrypi-armstubs}/armstub8-gic.bin firmware/
          cp ${pkgs.ubootRaspberryPi4_64bit}/u-boot.bin firmware/u-boot.bin
          cp ${configTxt} firmware/config.txt
        '';
        populateRootCommands = ''
          mkdir -p ./files/boot
          ${config.boot.loader.generic-extlinux-compatible.populateCmd} \
            -c ${config.system.build.toplevel} -d ./files/boot
        '';
      };
    };
}
