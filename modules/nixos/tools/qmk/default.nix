{ config, pkgs, lib, ... }:

with lib;
with lib.dafos;
let cfg = config.dafos.tools.qmk;
in
{
  options.dafos.tools.qmk = with types; {
    enable = mkBoolOpt false "Whether or not to enable QMK";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      qmk
    ];

    services.udev.packages = with pkgs; [
      qmk-udev-rules
    ];
  };
}
