{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkIf
    optionalString
    getExe
    ;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.programs.terminal.shells.zsh;
in
{
  options.${namespace}.programs.terminal.shells.zsh = {
    enable = mkEnableOption "Whether or not to enable zsh.";

    prompt-init = mkBoolOpt true "Whether or not to show an initial message when opening a new shell.";
  };

  config = mkIf cfg.enable {
    programs = {
      zsh = {
        enable = true;
        autosuggestion.enable = true;
        enableCompletion = true;
        syntaxHighlighting.enable = true;

        initContent =
          ''
            # Fix an issue with tmux.
            export KEYTIMEOUT=1

            # Use vim bindings.
            set -o vi

            # Improved vim bindings.
            source ${pkgs.zsh-vi-mode}/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh
          ''
          + optionalString cfg.prompt-init ''
            ${getExe pkgs.toilet} -f future "Dafos" --gay
          '';

        shellAliases = {
          say = "${getExe pkgs.toilet} -f pagga";
        };

        plugins = [
          {
            name = "zsh-nix-shell";
            file = "nix-shell.plugin.zsh";
            src = pkgs.fetchFromGitHub {
              owner = "chisui";
              repo = "zsh-nix-shell";
              rev = "v0.4.0";
              sha256 = "037wz9fqmx0ngcwl9az55fgkipb745rymznxnssr3rx9irb6apzg";
            };
          }
        ];
      };
    };
  };
}
