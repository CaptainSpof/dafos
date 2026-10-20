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

  cfg = config.${namespace}.hardware.cpu.amd;

  # nixpkgs' module aggregator now expects a kmodigest `.ko.cer` next to every
  # external module, but zenpower installs its `.ko` by hand and skips signing.
  zenpower = config.boot.kernelPackages.zenpower.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      ${lib.getExe pkgs.buildPackages.kmodigest} "$out"/lib/modules/*/kernel/drivers/hwmon/zenpower/zenpower.ko
    '';
  });
in
{
  options.${namespace}.hardware.cpu.amd = {
    enable = mkBoolOpt false "Whether or not to enable support for amd cpu.";
  };

  config = mkIf cfg.enable {
    boot = {
      extraModulePackages = [ zenpower ];

      kernelModules = [
        "kvm-amd" # amd virtualization
        "amd-pstate" # load pstate module in case the device has a newer gpu
        "zenpower" # zenpower is for reading cpu info, i.e voltage
        "msr" # x86 CPU MSR access device
      ];

      kernelParams = [ "amd_pstate=active" ];
    };

    environment.systemPackages = [ pkgs.amdctl ];

    hardware.cpu.amd.updateMicrocode = true;
  };
}
