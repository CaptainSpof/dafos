{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib)
    mkIf
    getExe
    boolToString
    types
    optionalString
    concatStringsSep
    ;
  inherit (lib.${namespace}) mkBoolOpt mkOpt;

  cfg = config.${namespace}.programs.graphical.apps.games.sisr;
  username = config.${namespace}.user.name;

  sisr = pkgs.${namespace}.sisr;

  # SISR (mirroring its upstream AppImage) treats the directory of its own
  # executable as a writable, stable home: it writes its ".initial_setup_done"
  # marker there and registers that exact path as the "SISR Marker" Steam
  # shortcut it later matches itself against. It reads that path from $APPIMAGE,
  # falling back to the real binary otherwise. Our real binary lives read-only
  # in the Nix store at a path that changes every rebuild, so on its own SISR
  # can neither persist setup nor recognise its own marker.
  #
  # Anchor a stable identity in $HOME: a launchable wrapper at a fixed path
  # that sets $APPIMAGE to itself, then hands off to the store binary. Crucially
  # EVERY entrypoint must funnel through this wrapper — if the raw store binary
  # is ever launched directly (e.g. off $PATH) it resolves its identity back to
  # the read-only store and setup breaks. So `SISR` on $PATH, the desktop entry,
  # and the Steam marker shortcut all point here; the store binary is never
  # exposed directly.
  stateDir = "/home/${username}/.local/share/SISR";
  wrapperPath = "${stateDir}/SISR";

  sisrLauncher = pkgs.writeShellScriptBin "SISR" ''
    exec ${wrapperPath} "$@"
  '';
in
{
  options.${namespace}.programs.graphical.apps.games.sisr = {
    enable = mkBoolOpt false "Whether or not to enable SISR (Steam Input System Redirector).";
    fullscreen = mkBoolOpt true ''
      Whether SISR's overlay window opens fullscreen (upstream default: true).
      Only configurable via the SISR_FULLSCREEN env var or a --window.fullscreen
      CLI flag, neither of which the desktop entry or the Steam "SISR Marker"
      shortcut can be made to pass through per-invocation, hence this option.
      NOTE: with fullscreen=false and showWindow left at its upstream default
      (false), SISR runs tray-only and shows no window at all — set showWindow
      too if you actually want a windowed UI.
    '';
    showWindow = mkBoolOpt false ''
      Whether SISR shows any window on startup at all (upstream default:
      false, i.e. tray-only). With fullscreen=true this also enables the
      Steam Overlay integration; with fullscreen=false it shows a normal
      windowed UI. Mirrors --window.show / SISR_SHOW_WINDOW upstream.
    '';
    ignoreControllers = mkOpt (types.listOf types.str) [ ] ''
      SDL VID/PID pairs (e.g. "0x2dc8/0x310b") that SISR should not pick up at all,
      via SDL_JOYSTICK_BLACKLIST_DEVICES in SISR's environment only — Steam Input and
      every other app still see the controller normally.

      SISR has no device filter of its own (no CLI flag, no config key, no UI toggle),
      so the only lever is SDL's own enumeration. It must be the *blacklist* hint:
      SISR unconditionally clobbers SDL_GAMECONTROLLER_IGNORE_DEVICES and
      SDL_HIDAPI_IGNORE_DEVICES to "" at startup, before SDL_InitSubSystem(GAMEPAD),
      so those two are useless here. SDL_ShouldIgnoreJoystick() checks the blacklist
      first and SISR never touches it, so the device is dropped before both the evdev
      and the HIDAPI backends ever surface it.
    '';
  };

  config = mkIf cfg.enable {
    # Only the launcher shim reaches $PATH — never the raw store binary.
    environment.systemPackages = [
      sisrLauncher
      (pkgs.makeDesktopItem {
        name = "sisr";
        desktopName = "SISR";
        comment = "Steam Input System Redirector";
        exec = wrapperPath;
        icon = "${sisr}/share/icons/hicolor/scalable/apps/sisr.svg";
        terminal = false;
        categories = [
          "Game"
          "Utility"
        ];
      })
    ];

    system.activationScripts.sisrWrapper = ''
      mkdir -p ${stateDir}
      cat > ${wrapperPath} <<'WRAPPER_EOF'
      #!/bin/sh
      export APPIMAGE="$0"
      export SISR_FULLSCREEN=${boolToString cfg.fullscreen}
      export SISR_SHOW_WINDOW=${boolToString cfg.showWindow}
      ${optionalString (
        cfg.ignoreControllers != [ ]
      ) "export SDL_JOYSTICK_BLACKLIST_DEVICES=${concatStringsSep "," cfg.ignoreControllers}"}
      exec ${getExe sisr} "$@"
      WRAPPER_EOF
      chmod 0755 ${wrapperPath}
      chown -R ${username}:users ${stateDir}
    '';

    # VIIPER (SISR's controller-emulation backend) attaches its emulated
    # devices through the USB/IP virtual host controller.
    boot.kernelModules = [ "vhci-hcd" ];

    systemd.services.viiper = {
      description = "VIIPER server";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      # VIIPER shells out to the usbip client to auto-attach devices locally.
      path = [ config.boot.kernelPackages.usbip ];
      serviceConfig = {
        ExecStart = "${getExe pkgs.${namespace}.viiper} server";
        Restart = "on-failure";
      };
    };

    # SISR talks to the Steam client through CEF remote debugging, which Steam
    # only enables when this marker file exists.
    systemd.user.tmpfiles.rules = [
      "f %h/.local/share/Steam/.cef-enable-remote-debugging 0644 - - - -"
    ];
  };
}
