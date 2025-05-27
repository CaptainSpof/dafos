{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt enabled disabled;

  cfg = config.${namespace}.suites.common-slim;
in
{
  options.${namespace}.suites.common-slim = {
    enable = mkBoolOpt false "Whether or not to enable common-slim configuration.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      cifs-utils
      pkgs.dafos.list-iommu
      powertop
    ];

    dafos = {
      nix = {
        enable = true;
        nh.enable = true;
      };

      hardware = {
        storage = enabled;
      };

      security = {
        doas = disabled;
      };

      services = {
        avahi = enabled;
        openssh = enabled;
        tailscale = enabled;
      };

      system = {
        boot = enabled;
        fonts = enabled;
        locale = enabled;
        networking = enabled;
        time = enabled;
        xkb = enabled;
      };
    };
  };
}
