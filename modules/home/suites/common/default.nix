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
    # GitHub access token for Nix (raises the 60 req/h unauthenticated GitHub
    # API limit hit during flake eval/update). Rendered from the SOPS secret
    # into a sops template and !include-d into the user's nix.conf so the token
    # never lands in the world-readable store.
    #
    # DISABLED until secrets/daf/github.yaml is re-keyed: it's encrypted to
    # admin + daftop + dafoltop only, not dafbox, so sops-nix activation fails on
    # dafbox. Re-key from a host that can decrypt it:
    #   sops updatekeys secrets/daf/github.yaml
    # then re-enable this block.
    #
    # sops = {
    #   secrets."github-access-token-flake-update" = {
    #     sopsFile = lib.snowfall.fs.get-file "secrets/daf/github.yaml";
    #   };
    #   templates."nix-access-tokens" = {
    #     content = ''
    #       access-tokens = github.com=${config.sops.placeholder."github-access-token-flake-update"}
    #     '';
    #   };
    # };
    #
    # nix.extraOptions = ''
    #   !include ${config.sops.templates."nix-access-tokens".path}
    # '';

    home.packages = with pkgs; [
      coreutils
      curl
      duf
      dust
      fd
      file
      findutils
      fzf
      killall
      lnav
      lsof
      pciutils
      procs
      unrar
      unzip
      wget
      wl-clipboard
      xclip
      xdotool
      xprop
      xwininfo
      ydotool
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
            alacritty = disabled;
            kitty = disabled;
            wezterm = enabled;
          };

          shells = {
            fish = enabled;
            nushell = disabled;
            zsh = disabled;
          };

          tools = {
            bat = enabled;
            bottom = enabled;
            carapace = enabled;
            comma = disabled;
            direnv = enabled;
            eza = enabled;
            fup-repl = enabled;
            git = enabled;
            home-manager = enabled;
            less = enabled;
            ripgrep = enabled;
            starship = enabled;
            zellij = disabled;
            zoxide = enabled;
          };
        };
      };

      services = {
        espanso = enabled;
      };
    };

    programs.readline = {
      enable = true;

      extraConfig = ''
        set completion-ignore-case on
      '';
    };

    xdg.configFile.wgetrc.text = "";
  };
}
