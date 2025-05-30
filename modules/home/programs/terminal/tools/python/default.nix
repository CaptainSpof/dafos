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

  cfg = config.${namespace}.programs.terminal.tools.python;
in
{
  options.${namespace}.programs.terminal.tools.python = {
    enable = mkBoolOpt false "Whether or not to enable python.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      (python.withPackages (
        ps: with ps; [
          pip
          pyqt5
          qtpy
          requests
        ]
      ))
    ];
  };
}
