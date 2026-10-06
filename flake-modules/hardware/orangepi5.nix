# Orange Pi 5 (RK3588S) on mainline: nixpkgs' default kernel (6.18 LTS)
# carries the board's device tree and every driver it needs. U-Boot
# (pkgs.ubootOrangePi5) lives in the SPI flash and boots the extlinux
# entries written here; see flake-modules/hosts/dafpi/README.md.
{
  flake.modules.nixos.orangepi5 = {
    nixpkgs.hostPlatform = "aarch64-linux";

    boot = {
      loader = {
        grub.enable = false;
        generic-extlinux-compatible.enable = true;
      };

      # The M.2 slot hangs off the PCIe 2.0 combo PHY, which is a module.
      initrd.availableKernelModules = [
        "nvme"
        "phy_rockchip_naneng_combphy"
      ];

      kernelParams = [
        # Debug UART (3-pin header) runs at 1.5 Mbaud; HDMI gets the console too.
        "console=ttyS2,1500000"
        "console=tty1"
        # Without these the NVMe (seen with a Kingston OM3PDP3, Steam Deck
        # OEM) drops into a power state it never leaves: read timeouts ~40 s
        # after boot, failed reset, device disabled until the next power
        # cycle. Tested 2026-10-06: steady 415 MB/s with both set.
        "nvme_core.default_ps_max_latency_us=0"
        "pcie_aspm=off"
      ];
    };

    hardware = {
      deviceTree.name = "rockchip/rk3588s-orangepi-5.dtb";
      # Mali (panthor) CSF firmware, among others.
      enableRedistributableFirmware = true;
    };
  };
}
