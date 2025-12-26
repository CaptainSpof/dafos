{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib) mkIf mkDefault;
  inherit (lib.${namespace}) mkBoolOpt enabled disabled;

  cfg = config.${namespace}.suites.common;
in
{
  options.${namespace}.suites.common = {
    enable = mkBoolOpt false "Whether or not to enable common configuration.";
  };

  config = mkIf cfg.enable {
    programs.localsend.enable = true;
    environment.systemPackages = with pkgs; [
      appimage-run
      cifs-utils
      gcc
      dafos.list-iommu
      powertop
      ripgrep
    ];

    dafos = {
      nix = {
        enable = true;
        nh.enable = true;
      };

      programs = {
        terminal = {
          tools = {
            bandwhich = enabled;
            nix-ld = enabled;
          };
        };
      };

      hardware = {
        audio = enabled;
        sensors = enabled;
        storage = enabled;
      };

      security = {
        doas = disabled;
        gpg = disabled;
        keyring.enable = config.${namespace}.desktop.gnome.enable;
      };

      services = {
        avahi = enabled;
        openssh = enabled;
        printing = mkDefault enabled;
        remote-desktop = enabled;
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
