{
  config,
  lib,
  namespace, inputs, pkgs,
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
    services.vicinae = {
      enable = true;
      systemd.autoStart = true;
      settings = {
        faviconService = "twenty";
        keybindingScheme = "emacs";
        font.size = 11;
        popToRootOnClose = false;
        closeOnFocusLoss = true;
        rootSearch.searchFiles = false;
        # theme.name = "matugen";
        window = {
          csd = true;
          opacity = 0.9;
          rounding = 12;
        };
      };
      extensions =
        with inputs.vicinae-extensions.packages.${pkgs.stdenv.hostPlatform.system}; [
          bluetooth
          firefox
          it-tools
          nix
          wifi-commander
        ];
    };
  };
}
