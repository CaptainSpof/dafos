{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.hardware.gpu.amd;
in
{
  options.${namespace}.hardware.gpu.amd = {
    enable = mkBoolOpt false "Whether or not to enable support for amdgpu.";
    amdvlk.enable = mkBoolOpt true "Whether or not to enable opencl support";
    opencl.enable = mkBoolOpt true "Whether or not to enable opencl support";
  };

  config = mkIf cfg.enable {
    # enable amdgpu kernel module
    boot = {
      initrd.kernelModules = [ "amdgpu" ]; # load amdgpu kernel module as early as initrd
      kernelModules = [ "amdgpu" ]; # if loading somehow fails during initrd but the boot continues, try again later
    };

    environment.systemPackages = with pkgs; [
      amdgpu_top
      nvtopPackages.amd
      lact
      ddcutil # control external monitors (brightness, etc.) over DDC/CI
    ];

    # Let the primary user talk to /dev/i2c-* without root, so DDC/CI controls
    # (external-monitor brightness) work unprivileged. Needs a re-login to apply.
    users.users.${config.${namespace}.user.name}.extraGroups = [ "i2c" ];

    services.lact.enable = true;

    environment.variables = {
      # VAAPI and VDPAU config for accelerated video.
      # See https://wiki.archlinux.org/index.php/Hardware_video_acceleration
      "VDPAU_DRIVER" = "radeonsi";
      "LIBVA_DRIVER_NAME" = "radeonsi";
    };

    # enables AMDVLK & OpenCL support
    hardware = {
      amdgpu = {
        # amdvlk = {
        #   inherit (cfg.amdvlk) enable;
        #   package = pkgs.amdvlk;

        #   support32Bit = {
        #     enable = true;
        #   };
        # };
        inherit (cfg) opencl;
      };

      # DDC/CI over the GPU's i2c buses: loads i2c-dev, creates /dev/i2c-*,
      # the i2c group, and the udev rules. Enables external-monitor brightness.
      i2c.enable = true;

      graphics = {
        enable = true;
        enable32Bit = true;
        extraPackages = with pkgs; [
          # mesa
          mesa

          # vulkan
          vulkan-tools
          vulkan-loader
          vulkan-validation-layers
          vulkan-extension-layer
        ];
      };
    };

    services.xserver.videoDrivers = lib.mkDefault [
      "modesetting"
      "amdgpu"
    ];
  };
}
