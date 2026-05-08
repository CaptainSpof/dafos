{
  config,
  lib,
  namespace,
  inputs,
  pkgs,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.programs.graphical.launchers.vicinae;
in
{
  options.${namespace}.programs.graphical.launchers.vicinae = {
    enable = mkBoolOpt false "Whether or not to use vicinae";
  };

  config = mkIf cfg.enable {
    programs.vicinae = {
      enable = true;
      systemd = {
        enable = true;
        autoStart = true;
      };
      settings = {
        keybinding_scheme = "Emacs";
        close_on_focus_loss = true;
        consider_preedit = true;
        pop_to_root_on_close = true;
        favicon_service = "twenty";
        search_files_in_root = true;
        font = {
          normal = {
            size = 12;
          };
        };
        theme = {
          light = {
            name = "vicinae-light";
            icon_theme = "default";
          };
          dark = {
            name = "vicinae-dark";
            icon_theme = "default";
          };
        };
        launcher_window = {
          opacity = 0.98;
        };
      };
      extensions = with inputs.vicinae-extensions.packages.${pkgs.stdenv.hostPlatform.system}; [
        bluetooth
        firefox
        it-tools
        nix
        power-profile
        wifi-commander
      ] ++ [
        # (config.lib.vicinae.mkRayCastExtension {
        #   name = "tailscale";
        #   rev = "bc92e53ae972e41a44800b2a4763a5b7bf69122e";
        #   sha256 = "sha256-7Fc/qengMNQFVM42Qvea7gn+HbEJs5Pgmu87f3RUPeg=";
        # })
      ];
    };
  };
}
