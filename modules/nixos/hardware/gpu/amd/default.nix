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
    ];

    environment.variables = {
      # VAAPI and VDPAU config for accelerated video.
      # See https://wiki.archlinux.org/index.php/Hardware_video_acceleration
      "VDPAU_DRIVER" = "radeonsi";
      "LIBVA_DRIVER_NAME" = "radeonsi";
    };

    # enables AMDVLK & OpenCL support
    hardware = {
      amdgpu = {
        amdvlk = {
          inherit (cfg.amdvlk) enable;
          package = pkgs.amdvlk;

          support32Bit = {
            enable = true;
          };
        };
        inherit (cfg) opencl;
      };

      graphics = {
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
