{
  config,
  pkgs,
  lib,
  namespace,
  ...
}:

let
  inherit (lib) mkIf mkDefault;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.hardware.storage;
in
{
  options.${namespace}.hardware.storage = {
    enable = mkBoolOpt false "Whether or not to enable support for extra storage devices.";
    ssdEnable = mkBoolOpt true "Whether or not to enable support for SSD storage devices.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      nfs-utils
      ntfs3g
    ];

    services.fstrim.enable = mkDefault cfg.ssdEnable;
  };
}
