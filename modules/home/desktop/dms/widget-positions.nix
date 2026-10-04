# Desktop-widget positions, saved per host.
#
# DMS keeps where each desktop widget sits in session.json, keyed by widget
# instance id and then by output name (plus `_synced`, a normalised position
# for widgets that sync across screens). Output names are per machine, so the
# positions are host data: each host keeps a `dms-widget-positions.json` next
# to its homes/<system>/daf@<host>/default.nix and points
# `dafos.desktop.dms.desktopWidgetPositions` at it.
#
# - `dms-save-widget-positions` writes that file from the live session.json,
#   keeping only the instances the current settings.json still knows.
# - On every switch, activation writes the saved keys back, so a widget moved
#   and not saved snaps back to its saved spot. A missing file (a host that
#   never saved) is skipped.
{ namespace }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.desktop.dms;

  sessionPath = "${config.xdg.stateHome}/DankMaterialShell/session.json";
  settingsPath = "${config.xdg.configHome}/DankMaterialShell/settings.json";

  file = cfg.desktopWidgetPositions;
  saved = if file != null && builtins.pathExists file then lib.importJSON file else null;

  # The session.json keys this owns; everything else in the file is left alone.
  select = "{desktopWidgetInstancePositions: (.desktopWidgetInstancePositions // {}), desktopWidgetGridSettings: (.desktopWidgetGridSettings // {})}";

  save = pkgs.writeShellApplication {
    name = "dms-save-widget-positions";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      flake=''${DAFOS_FLAKE:-$HOME/.config/dafos}
      dir="$flake/homes/${pkgs.stdenv.hostPlatform.system}/${config.home.username}@$(uname -n)"
      if [ ! -d "$dir" ]; then
        echo "no host directory at $dir (set DAFOS_FLAKE?)" >&2
        exit 1
      fi
      jq --slurpfile s ${lib.escapeShellArg settingsPath} '
        ($s[0].desktopWidgetInstances // [] | map(.id)) as $ids
        | ${select}
        | .desktopWidgetInstancePositions |= with_entries(select(.key as $k | $ids | index($k)))
      ' ${lib.escapeShellArg sessionPath} > "$dir/dms-widget-positions.json"
      echo "saved to $dir/dms-widget-positions.json"
    '';
  };
in
{
  options.${namespace}.desktop.dms.desktopWidgetPositions =
    mkOpt (with lib.types; nullOr path) null
      "This host's dms-widget-positions.json (written by dms-save-widget-positions); restored into session.json on switch.";

  config = lib.mkIf cfg.enable {
    home.packages = [ save ];

    # Same pattern as dmsDockApps: patch only our keys, only when they differ,
    # and restart DMS so its in-memory session doesn't save over the write.
    home.activation.dmsWidgetPositions = lib.mkIf (saved != null) (
      config.lib.dag.entryAfter [ "writeBoundary" ] ''
        session=${lib.escapeShellArg sessionPath}
        want=${lib.escapeShellArg (builtins.toJSON saved)}
        if [ -f "$session" ]; then
          current=$(${pkgs.jq}/bin/jq -cS '${select}' "$session")
          if [ "$current" != "$(printf '%s' "$want" | ${pkgs.jq}/bin/jq -cS .)" ]; then
            tmp=$(mktemp)
            ${pkgs.jq}/bin/jq --argjson p "$want" '. + $p' "$session" > "$tmp" \
              && run mv "$tmp" "$session"
            ${pkgs.systemd}/bin/systemctl --user restart dms.service 2>/dev/null || true
          fi
        fi
      ''
    );
  };
}
