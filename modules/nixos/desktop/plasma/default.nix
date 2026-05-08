{
  config,
  lib,
  namespace,
  pkgs,
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

    environment.plasma6.excludePackages = with pkgs.kdePackages; [
      # Multimedia
      elisa          # music player
      dragon         # video player (you have VLC)
      juk            # music manager

      akonadi
      akonadi-calendar
      akonadi-contacts
      akonadi-mime
      akonadi-search
      kmail
      korganizer
      merkuro        # calendar app
      kdepim-addons
      kdepim-runtime
      kaddressbook

      kalk
      konsole        # you use wezterm/alacritty
      khelpcenter    # offline documentation browser
      ksystemlog     # log viewer (you have lnav)
      filelight      # disk usage (you have du-dust, duf)
      kcolorchooser  # color picker

      # Printing
      print-manager  # printer manager

      # Remote desktop
      krdp           # RDP server

      # Discover (package manager GUI — you manage everything via Nix)
      discover

      # Partitioning (you have gparted already)
      partitionmanager

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
