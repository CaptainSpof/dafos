{
  config,
  lib,
  pkgs,
  inputs,
  namespace,
  ...
}:
let
  inherit (lib) types mkIf getExe';
  inherit (lib.${namespace}) mkBoolOpt mkOpt;

  cfg = config.${namespace}.programs.graphical.apps.games.gamemode;

  system = pkgs.stdenv.hostPlatform.system;
  dms = getExe' inputs.dank-material-shell.packages.${system}.dms-shell "dms";

  # Fully remove the DMS dock while gaming. `dock hide`/`reveal` toggle
  # showDock (the dock surface itself), so a cursor near the screen edge can't
  # pop it over a fullscreen game — unlike the autoHide/manualHide IPC, which
  # only flip the hover-reveal behaviour and would still show on hover.
  dockHide = "${dms} ipc call dock hide || true";
  dockReveal = "${dms} ipc call dock reveal || true";

  defaultStartScript = ''
    ${getExe' pkgs.libnotify "notify-send"} 'GameMode started' 'Dock Hidden'
  '';

  defaultEndScript = ''
    ${getExe' pkgs.libnotify "notify-send"} 'GameMode ended' 'Dock Revealed'
  '';
in
{
  options.${namespace}.programs.graphical.apps.games.gamemode = with types; {
    enable = mkBoolOpt false "Whether or not to enable gamemode.";
    endscript = mkOpt (nullOr str) null "The script to run when disabling gamemode.";
    startscript = mkOpt (nullOr str) null "The script to run when enabling gamemode.";
  };

  config =
    let
      # Hide the dock first, then run the user's (or default) start body;
      # reveal it again after the user's (or default) end body.
      startScript = pkgs.writeShellScript "gamemode-start" ''
        ${dockHide}
        ${if (cfg.startscript == null) then defaultStartScript else cfg.startscript}
      '';
      endScript = pkgs.writeShellScript "gamemode-end" ''
        ${if (cfg.endscript == null) then defaultEndScript else cfg.endscript}
        ${dockReveal}
      '';
    in
    mkIf cfg.enable {
      programs.gamemode = {
        enable = true;
        enableRenice = true;

        settings = {
          general = {
            softrealtime = "auto";
            renice = 15;
          };

          custom = {
            start = startScript.outPath;
            end = endScript.outPath;
          };
        };
      };

      security.wrappers.gamemode = {
        owner = "root";
        group = "root";
        source = "${getExe' pkgs.gamemode "gamemoderun"}";
        capabilities = "cap_sys_ptrace,cap_sys_nice+pie";
      };
    };
}
