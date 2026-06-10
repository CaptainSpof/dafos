{
  config,
  lib,
  namespace,
  pkgs,
  inputs,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.desktop.plasma;
in
{
  options.${namespace}.desktop.plasma = {
    enable = mkBoolOpt false "Whether or not to use plasma as the desktop environment.";
  };

  config = mkIf cfg.enable {
    dafos.system.xkb.enable = true;

    # KWin is launched by the system (display manager), so third-party KWin
    # effects must live in the system profile to be discoverable on its
    # QT_PLUGIN_PATH. Provides the `better_blur_dx` effect used in kwinrc.
    environment.systemPackages = [
      inputs.kwin-effects-better-blur-dx.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    environment.plasma6.excludePackages = with pkgs.kdePackages; [
      # Multimedia
      elisa # music player
      dragon # video player
      juk # music manager

      akonadi
      akonadi-calendar
      akonadi-contacts
      akonadi-mime
      akonadi-search
      kmail
      korganizer
      merkuro # calendar app
      kdepim-addons
      kdepim-runtime
      kaddressbook

      kalk
      khelpcenter # offline documentation browser

      # Printing
      print-manager # printer manager

      # Remote desktop
      krdp # RDP server

      # Discover (package manager GUI — you manage everything via Nix)
      discover

      plasma-sdk
    ];

    services = {
      desktopManager.plasma6.enable = true;
      libinput.enable = true;
      xserver.enable = true;
    };

    programs.dconf.enable = true;
    programs.kdeconnect.enable = true;
  };
}
