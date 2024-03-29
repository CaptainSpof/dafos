{ lib, config, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.dafos.cli-apps.neovim;
in
{
  options.dafos.cli-apps.neovim = {
    enable = mkEnableOption "Neovim";
  };

  config = mkIf cfg.enable {
    home = {
      packages = with pkgs; [
        less
        neovim
      ];

      sessionVariables = {
        PAGER = "less";
        MANPAGER = "less";
        NPM_CONFIG_PREFIX = "$HOME/.npm-global";
        EDITOR = "nvim";
      };

      shellAliases = {
        vimdiff = "nvim -d";
        vim = "nvim";
      };
    };

    xdg.configFile = {
      "dashboard-nvim/.keep".text = "";
    };
  };
}
