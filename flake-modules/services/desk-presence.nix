# Tells Home Assistant whether somebody is using this desktop: pushes
# {"active": bool, "activity": game|video|music|code|terminal|web|other|""}
# to an HA webhook every minute and on every change. Active =
# the session is unlocked (DMS lock screen) and there was input in the last
# idleSeconds; swayidle (ext-idle-notify) honours idle inhibitors, so a video
# or a game holding one counts as input. Suspend pushes false right away; once
# the pushes stop, HA turns the sensor off by itself after 3 min.
#
# The HA side (binary_sensor.desk_dafbox_in_use, the heating's use of it)
# lives in modules/nixos/services/home-assistant/desk_presence.nix; both read
# the webhook id from secrets/dafoltop/dafbox-presence.yaml.
{ inputs, ... }:
{
  flake.modules.homeManager.desk-presence =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib)
        mkEnableOption
        mkIf
        mkOption
        types
        ;

      cfg = config.dafos.services.desk-presence;

      push = pkgs.writeShellApplication {
        name = "desk-presence";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.curl
          pkgs.jq
          pkgs.playerctl
          pkgs.procps
          pkgs.swayidle
          config.programs.dank-material-shell.package
          config.programs.niri.package
        ];
        text = ''
          state="$XDG_RUNTIME_DIR/desk-presence"

          # What the screen shows, for the dashboard's desk icon: a running
          # Steam game wins, then a playing MPRIS player, then the focused
          # window's app.
          activity() {
            if pgrep -f 'SteamLaunch AppId=' >/dev/null; then
              echo game
              return
            fi
            local player
            player=$(playerctl -a metadata --format '{{status}}|{{playerName}}|{{xesam:url}}' 2>/dev/null |
              grep -m1 '^Playing|' || true)
            case "$player" in
              *'|spotify|'* | *'|strawberry|'* | *'|tidal'* | *music.youtube.com* | *deezer.com*) echo music; return ;;
              Playing*) echo video; return ;;
            esac
            case "$(niri msg -j focused-window 2>/dev/null | jq -r '.app_id // empty' | tr '[:upper:]' '[:lower:]')" in
              *emacs* | code | code-* | codium | *zed* | *jetbrains*) echo code ;;
              *wezterm* | *kitty* | foot | *alacritty* | *ghostty* | *konsole*) echo terminal ;;
              *firefox* | *chromium* | *chrome* | *zen*) echo web ;;
              steam | *gamescope* | *ryujinx* | *lutris* | *heroic*) echo game ;;
              *) echo other ;;
            esac
          }

          push() {
            local active=false what=""
            if [ "''${1:-}" != off ] &&
              [ "$(cat "$state" 2>/dev/null || echo active)" = active ] &&
              [ "$(dms ipc call lock isLocked 2>/dev/null)" != true ]; then
              active=true
              what=$(activity)
            fi
            curl -fsS --max-time 10 -o /dev/null -X POST \
              -H 'Content-Type: application/json' \
              -d "{\"active\": $active, \"activity\": \"$what\"}" \
              ${lib.escapeShellArg cfg.url}"/api/webhook/$(cat ${
                config.sops.secrets."dafbox-presence/webhook-id".path
              })" || echo "push to Home Assistant failed" >&2
          }

          case "''${1:-run}" in
            idle | active)
              echo "$1" >"$state"
              push
              ;;
            off) push off ;;
            run)
              echo active >"$state"
              swayidle -w \
                timeout ${toString cfg.idleSeconds} "$0 idle" resume "$0 active" \
                before-sleep "$0 off" &
              while true; do
                push
                sleep 60
              done
              ;;
          esac
        '';
      };
    in
    {
      options.dafos.services.desk-presence = {
        enable = mkEnableOption "pushing desk presence (session in use) to Home Assistant";

        url = mkOption {
          type = types.str;
          default = "https://home.daftdaf.dev";
          description = "Home Assistant instance holding the webhook.";
        };
        idleSeconds = mkOption {
          type = types.ints.positive;
          default = 300;
          description = "Seconds without input after which the desk counts as unused.";
        };
      };

      config = mkIf cfg.enable {
        sops.secrets."dafbox-presence/webhook-id" = {
          sopsFile = inputs.self + "/secrets/dafoltop/dafbox-presence.yaml";
          key = "webhook-id";
        };

        systemd.user.services.desk-presence = {
          Unit = {
            Description = "Push desk presence to Home Assistant";
            PartOf = [ "graphical-session.target" ];
            After = [
              "graphical-session.target"
              "sops-nix.service"
            ];
          };
          Service = {
            ExecStart = "${lib.getExe push} run";
            # Logging out or shutting down: unused now, not in 3 min.
            ExecStopPost = "${lib.getExe push} off";
            Restart = "on-failure";
            RestartSec = 10;
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };
      };
    };
}
