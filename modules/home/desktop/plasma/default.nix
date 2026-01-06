{
  config,
  lib,
  namespace,
  pkgs,
  ...
}:

let
  inherit (lib) mkIf types;
  inherit (lib.${namespace}) mkBoolOpt mkOpt enabled;

  cfg = config.${namespace}.desktop.plasma;

  defaultPackages = with pkgs; [
    # Apps
    kdePackages.accounts-qt
    kdePackages.kaccounts-integration
    kdePackages.kaccounts-providers
    kdePackages.kdesu
    kdePackages.plasma-nm
    kdePackages.signon-kwallet-extension
    kdePackages.signond
    # Utils
    kdotool
  ];
  fullPackages = with pkgs; [
    # kdePackages.itinerary
    kdePackages.kalk
    kdePackages.kcolorchooser
    kdePackages.ksystemlog
    kdePackages.kweather
    kdePackages.merkuro
    kdePackages.partitionmanager
  ];
in
{
  options.${namespace}.desktop.plasma = with types; {
    enable = mkBoolOpt false "Whether or not to use Plasma as the desktop environment.";

    extraPackages = mkOpt (listOf package) [ ] "Extra Packages to install";

    full = mkBoolOpt true "Whether or not to enable slim down version of plasma.";
    touchScreen = mkBoolOpt false "Whether or not to enable touch screen capabilities.";
    themeSwitcher = mkBoolOpt false "Whether or not to enable theme switcher service.";
  };

  config = mkIf cfg.enable {
    dafos = {
      desktop.addons.electron-support = enabled;
      services.koi.enable = cfg.themeSwitcher;
    };

    programs.plasma.enable = true;

    home.packages =
      with pkgs;
      (lib.optionals cfg.touchScreen [
        # Virtual keyboard
        maliit-framework
        maliit-keyboard
      ])
      ++ defaultPackages
      ++ (lib.optionals cfg.full fullPackages)
      ++ cfg.extraPackages;
  };
}
