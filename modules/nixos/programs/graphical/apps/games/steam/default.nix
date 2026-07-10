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
    types
    optionalAttrs
    concatStringsSep
    ;
  inherit (lib.${namespace}) mkBoolOpt mkOpt enabled;

  cfg = config.${namespace}.programs.graphical.apps.games.steam;
  gamesCfg = config.${namespace}.programs.graphical.apps.games;
in
{
  options.dafos.programs.graphical.apps.games.steam = {
    enable = mkBoolOpt false "Whether or not to enable support for Steam.";
    uiScaling = mkBoolOpt true "Whether or not to enable UI scaling for Steam.";
    ignoreControllers = mkOpt (types.listOf types.str) [ ] ''
      SDL VID/PID pairs (e.g. "0x045e/0x02ea") that Steam Input should ignore, via
      SDL_GAMECONTROLLER_IGNORE_DEVICES in Steam's environment only. Use this to keep a
      controller out of Steam Input's grab so another app can use it directly — e.g. a
      Sunshine-forwarded pad meant to be a separate player in an emulator, which SISR would
      otherwise fold into Player 1 via its forced Steam Input layout.
    '';
  };

  config = mkIf cfg.enable {
    programs.steam = {
      enable = true;
      extest.enable = true;
      localNetworkGameTransfers.openFirewall = true;
      protontricks.enable = true;
      remotePlay.openFirewall = true;
      extraCompatPackages = [ pkgs.proton-ge-bin ];
      platformOptimizations = enabled;
      package = pkgs.steam.override (
        {
          # Wayland (Niri) needs PipeWire for screen capture — required for
          # Remote Play streaming and in-game overlay screencasting.
          extraArgs = "-pipewire";
          # Steam's FHS sandbox resets PATH (and isolates /tmp), so host
          # binaries in /run/current-system/sw/bin are invisible to launch
          # options — `gamescope ... -- %command%` fails inside Steam with
          # "command not found" unless the tools live inside the sandbox.
          extraPkgs =
            p:
            lib.optional gamesCfg.gamescope.enable p.gamescope
            ++ lib.optional gamesCfg.gamemode.enable p.gamemode;
          # libgamemode.so must be dlopen-able by libgamemodeauto from both
          # 64-bit and 32-bit games, hence multiPkgs (extraLibraries) rather
          # than extraPkgs.
          extraLibraries = p: lib.optional gamesCfg.gamemode.enable p.gamemode.lib;
        }
        // optionalAttrs (cfg.ignoreControllers != [ ]) {
          extraEnv.SDL_GAMECONTROLLER_IGNORE_DEVICES = concatStringsSep "," cfg.ignoreControllers;
        }
      );
    };

    hardware.steam-hardware.enable = true;

    environment.systemPackages = with pkgs; [ steamtinkerlaunch ];

    environment.sessionVariables = {
      STEAM_EXTRA_COMPAT_TOOLS_PATHS = "$HOME/.steam/root/compatibilitytools.d";
      STEAM_FORCE_DESKTOPUI_SCALING = lib.optional cfg.uiScaling "2";
    };
  };
}
