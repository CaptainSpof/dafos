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
    kdePackages.kalk
    kdePackages.kcolorchooser
    kdePackages.koi
    kdePackages.ksystemlog
    kdePackages.kweather
    kdePackages.merkuro
    kdePackages.itinerary
    # Themes
    dafos.kde-warm-eyes
    dafos.leaf-kde
    dafos.plasma-applet-netspeed-widget
    gruvbox-gtk-theme
    kde-gruvbox
    papirus-icon-theme
    inputs.darkly.packages.${pkgs.system}.darkly-qt6
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
      desktop.addons = {
        electron-support = enabled;
      };
      services.koi.enable = cfg.themeSwitcher;
    };

    programs.plasma.enable = true;

    qt.enable = true;

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
