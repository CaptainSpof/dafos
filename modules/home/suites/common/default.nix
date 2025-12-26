{
  config,
  lib,
  namespace,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt enabled disabled;

  cfg = config.${namespace}.suites.common;
in
{
  options.${namespace}.suites.common = {
    enable = mkBoolOpt false "Whether or not to enable common configuration.";
  };

  config = mkIf cfg.enable {

    home.packages = with pkgs; [
      coreutils
      curl
      duf
      fd
      file
      findutils
      fzf
      killall
      lnav
      lsof
      pciutils
      procs
      ttyper
      unrar
      unzip
      wget
      xclip
      xdotool
      xorg.xprop
      xorg.xwininfo
      ydotool
      brave
    ];

    dafos = {
      programs = {
        graphical = {
          browsers = {
            firefox = enabled;
          };
          editors = {
            emacs = enabled;
          };
        };

        terminal = {
          emulators = {
            alacritty = enabled;
            kitty = enabled;
            wezterm = enabled;
          };

          shells = {
            fish = enabled;
            nushell = enabled;
            zsh = enabled;
          };

          tools = {
            bat = enabled;
            bottom = enabled;
            carapace = enabled;
            comma = enabled;
            direnv = enabled;
            eza = enabled;
            fup-repl = enabled;
            git = enabled;
            home-manager = enabled;
            less = enabled;
            ripgrep = enabled;
            starship = enabled;
            zellij = enabled;
            zoxide = enabled;
          };
        };
      };
      services = {
        espanso = disabled;
      };
    };

    programs.zen-browser.enable = true;

    programs.readline = {
      enable = true;

      extraConfig = ''
        set completion-ignore-case on
      '';
    };

    xdg.configFile.wgetrc.text = "";
  };
}
