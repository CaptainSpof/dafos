{
  config,
  inputs,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;

  dmsShell = inputs.dank-material-shell.packages.${pkgs.stdenv.hostPlatform.system}.dms-shell;

  cfg = config.${namespace}.display-managers.dms-greeter;
  autoLoginUser = config.services.displayManager.autoLogin.user;
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
      # dmsShell is the DMS flake package -- the same derivation home-manager
      # uses. Quickshell is no longer exported by the DMS flake (it warns and
      # aliases nixpkgs), so take it from pkgs.
      package = dmsShell;
      quickshell.package = pkgs.quickshell;

      # Pull the user's current DMS theme/wallpaper into the greeter.
      configHome = config.users.users.${autoLoginUser}.home;
    };
  };
}
