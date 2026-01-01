{
  config,
  lib,
  namespace,
  pkgs,
  inputs,
  ...
}:

let
  inherit (lib) mkIf types;
  inherit (lib.${namespace}) mkBoolOpt mkOpt enabled;

  cfg = config.${namespace}.desktop.plasma;

  defaultPackages = with pkgs; [
    # Apps
    kdePackages.accounts-qt
    # kdePackages.itinerary
    kdePackages.kaccounts-integration
    kdePackages.kaccounts-providers
    kdePackages.kalk
    kdePackages.kcolorchooser
    kdePackages.kdesu
    kdePackages.koi
    kdePackages.ksystemlog
    kdePackages.kweather
    kdePackages.merkuro
    kdePackages.plasma-nm
    kdePackages.partitionmanager
    kdePackages.signon-kwallet-extension
    kdePackages.signond
    # Themes
    dafos.kde-warm-eyes
    dafos.leaf-kde
    dafos.plasma-applet-netspeed-widget
    gruvbox-gtk-theme
    kde-gruvbox
    papirus-icon-theme
    inputs.darkly.packages.${pkgs.stdenv.hostPlatform.system}.darkly-qt6
    # Utils
    kdotool
    wl-clipboard
  ];
in
{
  options.${namespace}.desktop.plasma = with types; {
    enable = mkBoolOpt false "Whether or not to use Plasma as the desktop environment.";

    extraPackages = mkOpt (listOf package) [ ] "Extra Packages to install";

    touchScreen = mkBoolOpt false "Whether or not to enable touch screen capabilities.";
    themeSwitcher = mkBoolOpt false "Whether or not to enable theme switcher service.";
  };

  config = mkIf cfg.enable {
    dafos = {
      desktop.addons.electron-support = enabled;
      services.koi.enable = cfg.themeSwitcher;
    };

    programs.plasma.enable = true;

    home.sessionVariables = {
      QT_QPA_PLATFORMTHEME = "qt6ct";
      QT_QPA_PLATFORMTHEME_QT6 = "qt6ct";
    };

    qt = {
      enable = true;
      style.package = [
        inputs.darkly.packages.${pkgs.stdenv.hostPlatform.system}.darkly-qt5
        inputs.darkly.packages.${pkgs.stdenv.hostPlatform.system}.darkly-qt6
      ];
      # platformTheme.name = "kde6";
    };

    home.packages =
      with pkgs;
      (lib.optionals cfg.touchScreen [
        # Virtual keyboard
        maliit-framework
        maliit-keyboard
      ])
      ++ defaultPackages
      ++ cfg.extraPackages;
  };
}
