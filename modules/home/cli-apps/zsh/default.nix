{ lib, config, pkgs, ... }:

with lib;
with lib.dafos;
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.dafos.cli-apps.zsh;
in
{
  options.dafos.cli-apps.zsh = {
    enable = mkEnableOption "ZSH";

    prompt-init = mkBoolOpt true "Whether or not to show an initial message when opening a new shell.";
  };

  config = mkIf cfg.enable {
    programs = {
      zsh = {
        enable = true;
        enableAutosuggestions = true;
        enableCompletion = true;
        syntaxHighlighting.enable = true;

        initExtra = ''
          # Fix an issue with tmux.
          export KEYTIMEOUT=1

          # Use vim bindings.
          set -o vi

          # Improved vim bindings.
          source ${pkgs.zsh-vi-mode}/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh
        ''+ optionalString cfg.prompt-init ''
              ${pkgs.toilet}/bin/toilet -f future "Dafos" --gay
            '';

        shellAliases = {
          say = "${pkgs.toilet}/bin/toilet -f pagga";
        };

        plugins = [{
          name = "zsh-nix-shell";
          file = "nix-shell.plugin.zsh";
          src = pkgs.fetchFromGitHub {
            owner = "chisui";
            repo = "zsh-nix-shell";
            rev = "v0.4.0";
            sha256 = "037wz9fqmx0ngcwl9az55fgkipb745rymznxnssr3rx9irb6apzg";
          };
        }];
      };
    };
  };
}
