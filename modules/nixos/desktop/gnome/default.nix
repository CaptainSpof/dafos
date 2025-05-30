# TODO: move to modules/home
{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib)
    optional
    mkIf
    mapAttrs
    mkDefault
    types
    ;
  inherit (lib.${namespace}) mkOpt mkBoolOpt;
  inherit (lib.home-manager.hm.gvariant) mkTuple;

  cfg = config.${namespace}.desktop.gnome;
  gdmHome = config.users.users.gdm.home;

  defaultExtensions = with pkgs.gnomeExtensions; [
    appindicator
    aylurs-widgets
    clipboard-indicator-2
    dash-to-dock
    emoji-selector
    forge
    gsconnect
    gtile
    just-perfection
    logo-menu
    middle-click-to-close-in-overview
    no-overview
    remove-app-menu
    space-bar
    top-bar-organizer
    wireless-hid
  ];

  default-attrs = mapAttrs (_key: mkDefault);
  nested-default-attrs = mapAttrs (_key: default-attrs);
in
{
  options.${namespace}.desktop.gnome = with types; {
    enable = mkBoolOpt false "Whether or not to use Gnome as the desktop environment.";
    wallpaper = {
      light = mkOpt (oneOf [
        str
        package
      ]) pkgs.dafos.wallpapers.nord-rainbow-light-nix "The light wallpaper to use.";
      dark = mkOpt (oneOf [
        str
        package
      ]) pkgs.dafos.wallpapers.nord-rainbow-dark-nix "The dark wallpaper to use.";
    };
    color-scheme = mkOpt (enum [
      "light"
      "dark"
    ]) "dark" "The color scheme to use.";
    wayland = mkBoolOpt true "Whether or not to use Wayland.";
    autoSuspend = mkBoolOpt true "Whether or not to suspend the machine after inactivity.";
    monitors = mkOpt (nullOr path) null "The monitors.xml file to create.";
    extensions = mkOpt (listOf package) [ ] "Extra Gnome extensions to install.";
  };

  config = mkIf cfg.enable {
    dafos = {
      system.xkb.enable = true;
    };

    environment.systemPackages =
      with pkgs;
      [
        (hiPrio xdg-open-with-portal)
        wl-clipboard
        gnome.gnome-tweaks
        gnome.nautilus-python
      ]
      ++ defaultExtensions
      ++ cfg.extensions;

    environment.gnome.excludePackages = with pkgs.gnome; [
      pkgs.gnome-tour
      epiphany
      geary
      gnome-font-viewer
      gnome-system-monitor
      gnome-maps
    ];

    systemd.tmpfiles.rules =
      [ "d ${gdmHome}/.config 0711 gdm gdm" ]
      ++ (
        # "./monitors.xml" comes from ~/.config/monitors.xml when GNOME
        # display information is updated.
        lib.optional (cfg.monitors != null) "L+ ${gdmHome}/.config/monitors.xml - - - - ${cfg.monitors}"
      );

    systemd.services.dafos-user-icon = {
      before = [ "display-manager.service" ];
      wantedBy = [ "display-manager.service" ];

      serviceConfig = {
        Type = "simple";
        User = "root";
        Group = "root";
      };

      script = ''
        config_file=/var/lib/AccountsService/users/${config.${namespace}.user.name}
        icon_file=/run/current-system/sw/share/dafos-icons/user/${config.${namespace}.user.name}/${
          config.${namespace}.user.icon.fileName
        }

        if ! [ -d "$(dirname "$config_file")"]; then
          mkdir -p "$(dirname "$config_file")"
        fi

        if ! [ -f "$config_file" ]; then
          echo "[User]
          Session=gnome
          SystemAccount=false
          Icon=$icon_file" > "$config_file"
        else
          icon_config=$(sed -E -n -e "/Icon=.*/p" $config_file)

          if [[ "$icon_config" == "" ]]; then
            echo "Icon=$icon_file" >> $config_file
          else
            sed -E -i -e "s#^Icon=.*$#Icon=$icon_file#" $config_file
          fi
        fi
      '';
    };

    # Required for app indicators
    services.udev.packages = with pkgs; [ gnome3.gnome-settings-daemon ];

    services.xserver = {
      enable = true;

      libinput.enable = true;
      displayManager.gdm = {
        enable = true;
        inherit (cfg) wayland autoSuspend;
      };
      desktopManager.gnome.enable = true;
    };

    dafos.home.extraOptions = {
      dconf.settings =
        let
          get-wallpaper =
            wallpaper: if lib.isDerivation wallpaper then builtins.toString wallpaper else wallpaper;
        in
        nested-default-attrs {
          "org/gnome/shell" = {
            disable-user-extensions = false;
            enabled-extensions =
              (builtins.map (extension: extension.extensionUuid) (cfg.extensions ++ defaultExtensions))
              ++ [
                "native-window-placement@gnome-shell-extensions.gcampax.github.com"
                "drive-menu@gnome-shell-extensions.gcampax.github.com"
                "user-theme@gnome-shell-extensions.gcampax.github.com"
              ];
            favorite-apps =
              [ "org.gnome.Nautilus.desktop" ]
              ++ optional config.${namespace}.apps.kitty.enable "kitty.desktop"
              ++ optional config.${namespace}.apps.discord.enable "discord.desktop"
              ++ optional config.${namespace}.apps.element.enable "element-desktop.desktop"
              ++ optional config.${namespace}.apps.steam.enable "steam.desktop";
          };

          "org/gnome/desktop/background" = {
            picture-uri = get-wallpaper cfg.wallpaper.light;
            picture-uri-dark = get-wallpaper cfg.wallpaper.dark;
          };
          "org/gnome/desktop/screensaver" = {
            picture-uri = get-wallpaper cfg.wallpaper.light;
            picture-uri-dark = get-wallpaper cfg.wallpaper.dark;
          };
          "org/gnome/desktop/interface" = {
            color-scheme = if cfg.color-scheme == "light" then "default" else "prefer-dark";
            enable-hot-corners = false;
          };
          "org/gnome/desktop/input-sources" = {
            show-all-sources = true;
            sources = [
              (mkTuple [
                "xkb"
                "fr+bepo"
              ])
              (mkTuple [
                "xkb"
                "us+altgr-intl"
              ])
            ];
          };
          "org/gnome/desktop/peripherals/touchpad" = {
            disable-while-typing = false;
            tap-to-click = true;
          };
          "org/gnome/desktop/wm/preferences" = {
            num-workspaces = 10;
            resize-with-right-button = true;
          };
          "org/gnome/desktop/wm/keybindings" = {
            close = [
              "<Alt>F4"
              "<Super>q"
            ];
            minimize = [ "<Ctrl><Super>h" ];

            switch-to-workspace-left = [ "<Super>g" ];
            switch-to-workspace-right = [ "<Super>h" ];
            switch-to-workspace-1 = [ "<Super>1" ];
            switch-to-workspace-2 = [ "<Super>2" ];
            switch-to-workspace-3 = [ "<Super>3" ];
            switch-to-workspace-4 = [ "<Super>4" ];
            switch-to-workspace-5 = [ "<Super>5" ];
            switch-to-workspace-6 = [ "<Super>6" ];
            switch-to-workspace-7 = [ "<Super>7" ];
            switch-to-workspace-8 = [ "<Super>8" ];
            switch-to-workspace-9 = [ "<Super>9" ];
            switch-to-workspace-10 = [ "<Super>0" ];

            move-to-workspace-left = [ "<Shift><Super>g" ];
            move-to-workspace-right = [ "<Shift><Super>h" ];
            move-to-workspace-1 = [ "<Shift><Super>1" ];
            move-to-workspace-2 = [ "<Shift><Super>2" ];
            move-to-workspace-3 = [ "<Shift><Super>3" ];
            move-to-workspace-4 = [ "<Shift><Super>4" ];
            move-to-workspace-5 = [ "<Shift><Super>5" ];
            move-to-workspace-6 = [ "<Shift><Super>6" ];
            move-to-workspace-7 = [ "<Shift><Super>7" ];
            move-to-workspace-8 = [ "<Shift><Super>8" ];
            move-to-workspace-9 = [ "<Shift><Super>9" ];
            move-to-workspace-10 = [ "<Shift><Super>0" ];
          };
          "org/gnome/shell/keybindings" = {
            # Remove the default hotkeys for opening favorited applications.
            switch-to-application-1 = [ ];
            switch-to-application-2 = [ ];
            switch-to-application-3 = [ ];
            switch-to-application-4 = [ ];
            switch-to-application-5 = [ ];
            switch-to-application-6 = [ ];
            switch-to-application-7 = [ ];
            switch-to-application-8 = [ ];
            switch-to-application-9 = [ ];
            switch-to-application-10 = [ ];
          };
          "org/gnome/mutter" = {
            edge-tiling = true;
            dynamic-workspaces = true;
          };

          "org/gnome/shell/extensions/dash-to-dock" = {
            autohide = true;
            dock-fixed = false;
            dock-position = "BOTTOM";
            pressure-threshold = 150.0;
            require-pressure-to-show = true;
            show-favorites = true;
            hot-keys = false;
          };

          "org/gnome/shell/extensions/just-perfection" = {
            panel-size = 48;
            activities-button = false;
          };

          "org/gnome/shell/extensions/Logo-menu" = {
            hide-softwarecentre = true;

            # Use right click to open Activities.
            menu-button-icon-click-type = 3;

            # Use the NixOS logo.
            menu-button-icon-image = 23;

            # menu-button-terminal =
            #   if config.${namespace}.desktop.addons.term.enable then
            #     lib.getExe config.${namespace}.desktop.addons.term.pkg
            #   else
            #     lib.getExe pkgs.gnome.gnome-terminal;
          };

          "org/gnome/shell/extensions/aylurs-widgets" = {
            background-clock = false;
            battery-bar = false;
            dash-board = false;
            date-menu-date-format = "%H:%M  %B %d";
            date-menu-hide-clocks = true;
            date-menu-hide-system-levels = true;
            date-menu-hide-user = true;

            # Hide the indincator
            date-menu-indicator-position = 2;

            media-player = false;
            media-player-prefer = "firefox";
            notification-indicator = false;
            power-menu = false;
            quick-toggles = false;
            workspace-indicator = false;
          };

          "org/gnome/shell/extensions/forge" = {
            window-gap-hidden-on-single = true;
          };

          "org/gnome/shell/extensions/forge/keybindings" = {
            con-split-horizontal = [ ];
            con-split-layout-toggle = [ ];
            con-split-vertical = [ ];
            con-stacked-layout-toggle = [ "<Alt><Super>s" ];
            con-tabbed-layout-toggle = [ "<Alt><Super>t" ];
            con-tabbed-showtab-decoration-toggle = [ "<Control><Alt>y" ];
            focus-border-toggle = [ ];
            prefs-tiling-toggle = [ "<Super>w" ];
            window-focus-down = [ "<Super>t" ];
            window-focus-left = [ "<Super>c" ];
            window-focus-right = [ "<Super>r" ];
            window-focus-up = [ "<Super>s" ];
            window-swap-down = [ "<Shift><Super>t" ];
            window-swap-left = [ "<Shift><Super>c" ];
            window-swap-right = [ "<Shift><Super>r" ];
            window-swap-up = [ "<Shift><Super>s" ];
            window-toggle-float = [ "<Super>f" ];
          };
          "org/gnome/shell/extensions/top-bar-organizer" = {
            left-box-order = [
              "menuButton"
              "activities"
              "dateMenu"
              "appMenu"
            ];

            center-box-order = [ "Space Bar" ];

            right-box-order = [
              "keyboard"
              "EmojisMenu"
              "wireless-hid"
              "drive-menu"
              "vitalsMenu"
              "screenRecording"
              "screenSharing"
              "dwellClick"
              "a11y"
              "quickSettings"
            ];
          };

          "org/gnome/shell/extensions/space-bar/shortcuts" = {
            enable-activate-workspace-shortcuts = false;
          };
          "org/gnome/shell/extensions/space-bar/behavior" = {
            show-empty-workspaces = false;
          };

          "org/gnome/shell/extensions/gtile" = {
            show-icon = false;
            grid-sizes = "8x2,4x2,2x2";
          };
        };
    };

    programs.kdeconnect = {
      enable = true;
      package = pkgs.gnomeExtensions.gsconnect;
    };

    # Open firewall for samba connections to work.
    networking.firewall.extraCommands = "iptables -t raw -A OUTPUT -p udp -m udp --dport 137 -j CT --helper netbios-ns";
  };
}
