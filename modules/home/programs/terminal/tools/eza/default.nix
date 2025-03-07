{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib) getExe mkForce mkIf;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.programs.terminal.tools.eza;
in
{
  options.${namespace}.programs.terminal.tools.eza = {
    enable = mkBoolOpt false "Whether or not to enable eza.";
  };

  config = mkIf cfg.enable {
    programs.eza = {
      enable = true;
      package = pkgs.eza;

      enableBashIntegration = true;
      enableFishIntegration = true;
      enableNushellIntegration = true;
      enableZshIntegration = true;

      extraOptions = [
        "--color-scale"
        "--group-directories-first"
        "--header"
      ];

      git = true;
      icons = "auto";
    };

    home.shellAliases = {
      la = mkForce "${getExe config.programs.eza.package} -lah --tree";
      sl = "ls";
      tree = mkForce "${getExe config.programs.eza.package} --tree --icons=always";
    };
  };
}
