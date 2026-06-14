{
  config,
  lib,
  pkgs,
  inputs,
  namespace,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.display-managers.dms-greeter;
  autoLoginUser = config.services.displayManager.autoLogin.user;
  system = pkgs.stdenv.hostPlatform.system;
in
{
  options.${namespace}.display-managers.dms-greeter = {
    enable = mkBoolOpt false "Whether or not to use the DankMaterialShell greeter (via greetd).";
  };

  config = mkIf cfg.enable {
    # Only one display manager may own the seat.
    services.xserver.displayManager.lightdm.enable = false;

    services.displayManager.dms-greeter = {
      enable = true;
      compositor.name = "niri";

      # Match the same DMS/quickshell build used by home-manager
      # (programs.dank-material-shell) so the greeter's copy of the user's
      # settings.json/session.json/colors.json (via configHome) stays
      # schema-compatible with the theme it was written by.
      package = inputs.dank-material-shell.packages.${system}.dms-shell;
      quickshell.package = inputs.dank-material-shell.packages.${system}.quickshell;

      # Pull the user's current DMS theme/wallpaper into the greeter.
      configHome = config.users.users.${autoLoginUser}.home;
    };
  };
}
