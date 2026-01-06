{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf getExe;
  inherit (config.${namespace}.programs.terminal.tools) starship;

  cfg = config.${namespace}.programs.terminal.shells.fish;
in
{
  options.${namespace}.programs.terminal.shells.fish = {
    enable = mkEnableOption "Whether or not to enable fish.";
  };

  config = mkIf cfg.enable {
    programs = {
      fish = {
        enable = true;

        shellInit = mkIf starship.enable ''
          starship init fish | source
        '';

        interactiveShellInit = ''
          set fzf_history_opts "--bind=ctrl-r:toggle-sort,ctrl-z:ignore"
          set -a fzf_history_opts "--nth=4.."
          bind \cr _fzf_search_history # HACK: override CTRL+R binding to the one defined in fzf.fish plugin
          # fix emacs dumb term
          if test "$TERM" = "dumb"
           function fish_title; end
          end

          function vterm_printf;
              if begin; [  -n "$TMUX" ]  ; and  string match -q -r "screen|tmux" "$TERM"; end
                  # tell tmux to pass the escape sequences through
                  printf "\ePtmux;\e\e]%s\007\e\\" "$argv"
              else if string match -q -- "screen*" "$TERM"
                  # GNU screen (screen, screen-256color, screen-256color-bce)
                  printf "\eP\e]%s\007\e\\" "$argv"
              else
                  printf "\e]%s\e\\" "$argv"
              end
          end

          function vterm_cmd --description 'Run an Emacs command among the ones been defined in vterm-eval-cmds.'
              set -l vterm_elisp ()
              for arg in $argv
                  set -a vterm_elisp (printf '"%s" ' (string replace -a -r '([\\\\"])' '\\\\\\\\$1' $arg))
              end
              vterm_printf '51;E'(string join "" $vterm_elisp)
          end
        '';

        functions = {
          fish_greeting = ''
            ${getExe pkgs.toilet} -f future --gay "Dafos"
          '';
          rm = "${getExe pkgs.trash-cli} $argv";
          fwifi = {
            body = "nmcli -t -f SSID device wifi list | grep . | sk | xargs -o -I_ nmcli --ask dev wifi connect '_'";
            description = "Fuzzy connect to a wifi";
          };
        };

        shellAbbrs = rec {

          # navigation
          "~~" = "cd $(git rev-parse --show-toplevel)";

          # nix
          n = "nix";
          ns = "nix search --no-update-lock-file nixpkgs";
          nf = "nix flake";
          nfu = "nix flake update";
          nepl = "nix repl '<nixpkgs>'";
          nr = ''nixos-rebuild --use-remote-sudo --flake "$(pwd)#$(hostname)"'';
          nR = "nix run nixpkgs#";
          nS = "nix shell nixpkgs#";
          nrb = "${nr} build";
          nrs = "${nr} switch";
          nhs = "nh os switch .";
          nhb = "nh os build .";
          nhc = "nh clean all";
          ncl = ''sudo nix-env -p /nix/var/nix/profiles/system --delete-generations +10'';
          ngc = "nix store gc --debug";
          ndiff = "nix store diff-closures /nix/var/nix/profiles/(ls -r /nix/var/nix/profiles/ | grep -E 'system\-' | sed -n '2 p') /nix/var/nix/profiles/system";
          froots = "find -H /nix/var/nix/gcroots/auto -type l | xargs -I {} sh -c 'readlink {}; realpath {}; echo'"; # find gc roots

          # rm
          rmf = "rm -rf";

          # systemd
          sys = "sudo systemctl";
          sysu = "systemctl --user";
          j = {
            expansion = "journalctl % | lnav";
            setCursor = true;
          };
          jb = {
            expansion = "journalctl -b % | lnav";
            setCursor = true;
          };
          ju = {
            expansion = "journalctl -u % | lnav";
            setCursor = true;
          };

          # misc
          q = "exit";
          mkdir = "mkdir -pv";
          y = "wl-copy";
          p = "wl-paste";
          pp = "pwd";
        };

        plugins = [
          {
            name = "done";
            src = pkgs.fishPlugins.done;
          }
          {
            name = "puffer-fish";
            src = pkgs.fishPlugins.puffer;
          }
          {
            name = "pisces";
            src = pkgs.fishPlugins.pisces;
          }
          {
            name = "fzf.fish";
            src = pkgs.fetchFromGitHub {
              owner = "PatrickF1";
              repo = "fzf.fish";
              rev = "8920367cf85eee5218cc25a11e209d46e2591e7a";
              sha256 = "sha256-nTiFD8vWjafYE4HNemyoUr+4SgsqN3lIJlNX6IGk+aQ=";
            };
          }
          {
            name = "colored-man-pages";
            src = pkgs.fishPlugins.colored-man-pages;
          }
          # {
          #   name = "async-prompt";
          #   inherit (pkgs.fishPlugins.async-prompt) src;
          # }
        ];
      };
    };
  };
}
