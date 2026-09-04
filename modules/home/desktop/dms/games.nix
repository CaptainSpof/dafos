# Curried on `namespace`: snowfall provides that argument only to the modules it
# discovers itself, so a file pulled in through `imports` has to be handed it
# explicitly (reading it from _module.args here is an infinite recursion).
{ namespace }:
{
  config,
  lib,
  pkgs,
  ...
}:
# The DMS "Games" folder: one launcher entry you step into, instead of every
# installed game sitting flat in the app drawer.
#
# Two halves that have to agree on what a game is:
#   - dms-games-sync (./games-sync.py) classifies desktop entries and writes
#     games.json, then adds those same desktop ids to DankMaterialShell's
#     session.json `hiddenApps` so they leave the flat list;
#   - the gamesFolder plugin (./plugins/games) reads games.json and launches
#     entries through SessionService, so per-app overrides and frecency still
#     apply.
# The rule lives only in the script — the plugin never classifies anything.
#
# Search is unaffected: DMS queries every launcher plugin in "all" mode, so
# typing a game's name still finds it even though its app entry is hidden.
let
  inherit (lib)
    concatStringsSep
    mkIf
    mkMerge
    getExe
    getExe'
    optional
    types
    ;
  inherit (lib.${namespace}) mkOpt mkBoolOpt;

  cfg = config.${namespace}.desktop.dms;
  gamesCfg = cfg.gamesFolder;

  stateDir = "${config.xdg.stateHome}/dms-games";
  sessionFile = "${config.xdg.stateHome}/DankMaterialShell/session.json";
  pluginSettingsFile = "${config.xdg.configHome}/DankMaterialShell/plugin_settings.json";

  sync = pkgs.writers.writePython3Bin "dms-games-sync" { flakeIgnore = [ "E501" ]; } (
    builtins.readFile ./games-sync.py
  );

  syncEnvironment = [
    "DMS_GAMES_STATE_DIR=${stateDir}"
    "DMS_SESSION_FILE=${sessionFile}"
    "DMS_BIN=${getExe' config.programs.dank-material-shell.package "dms"}"
    "SYSTEMCTL_BIN=${getExe' pkgs.systemd "systemctl"}"
  ]
  ++ optional (
    gamesCfg.includeIds != [ ]
  ) "DMS_GAMES_INCLUDE_IDS=${concatStringsSep "," gamesCfg.includeIds}"
  ++ optional (
    gamesCfg.excludeIds != [ ]
  ) "DMS_GAMES_EXCLUDE_IDS=${concatStringsSep "," gamesCfg.excludeIds}";

  syncEnvArgs = concatStringsSep " " (map lib.escapeShellArg syncEnvironment);
in
{
  options.${namespace}.desktop.dms.gamesFolder = {
    enable = mkBoolOpt config.${namespace}.suites.games.enable ''
      Collapse installed games into a single "Games" folder in the DMS app
      drawer instead of listing each one in the flat app list.
    '';

    includeIds = mkOpt (types.listOf types.str) [ ] ''
      Desktop entry ids (file basename without .desktop) to force into the
      Games folder, for games the Categories heuristic misses.
    '';

    excludeIds = mkOpt (types.listOf types.str) [ ] ''
      Desktop entry ids to keep out of the Games folder, on top of the
      launcher/manager entries the script already knows about. These stay
      visible in the normal app list.
    '';
  };

  config = mkMerge [
    (mkIf (cfg.enable && gamesCfg.enable) {
      home.packages = [ sync ];

      programs.dank-material-shell.plugins.gamesFolder.src = ./plugins/games;

      # Plugin enable-state is runtime-owned (see ./plugins.nix); seed it once so
      # the folder works on first login, then leave the toggle to the DMS UI.
      home.activation.dmsGamesPlugin = config.lib.dag.entryAfter [ "writeBoundary" ] ''
        settings=${lib.escapeShellArg pluginSettingsFile}
        run mkdir -p "$(dirname "$settings")"
        [ -f "$settings" ] || run sh -c "echo '{}' > \"$settings\""
        if [ "$(${pkgs.jq}/bin/jq -r 'has("gamesFolder")' "$settings")" != "true" ]; then
          tmp=$(mktemp)
          ${pkgs.jq}/bin/jq '.gamesFolder = { "enabled": true }' "$settings" > "$tmp" \
            && run mv "$tmp" "$settings"
        fi
      '';

      systemd.user.services.dms-games-sync = {
        Unit = {
          Description = "Sync the DMS Games launcher folder";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };

        Install.WantedBy = [ "graphical-session.target" ];

        Service = {
          Type = "oneshot";
          ExecStart = getExe sync;
          Environment = syncEnvironment;
        };
      };

      # Steam and Lutris write their per-game shortcuts here; re-sync whenever
      # the directory changes so a freshly installed game lands in the folder
      # (and a removed one stops being hidden) without a rebuild.
      systemd.user.paths.dms-games-sync = {
        Unit.Description = "Watch desktop entries for new or removed games";
        Path = {
          PathChanged = "${config.xdg.dataHome}/applications";
          Unit = "dms-games-sync.service";
        };
        Install.WantedBy = [ "paths.target" ];
      };
    })

    # Turning the folder off has to put the games back in the app list — the
    # hiding lives in DMS's own session state, which no longer has an owner once
    # the units are gone. A no-op when the folder was never enabled here.
    (mkIf (cfg.enable && !gamesCfg.enable) {
      home.activation.dmsGamesUnhide = config.lib.dag.entryAfter [ "writeBoundary" ] ''
        run env ${syncEnvArgs} ${getExe sync} --unhide
      '';
    })
  ];
}
