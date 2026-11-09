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

  cfg = config.${namespace}.programs.graphical.apps.handy;

  # Handy's own tray icon changes while recording, but DMS tints tray icons
  # monochrome, which makes the states hard to tell apart. Mirror the tray
  # state in a persistent notification instead. The source of truth is the
  # "tray apply: icon=..." line Handy logs on every state change (needs
  # log_level=debug, the current setting), so the indicator follows what
  # Handy really does rather than what the keybinding asked for.
  recordingIndicator = pkgs.writeShellApplication {
    name = "handy-recording-indicator";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      libnotify
      procps
      glib
    ];
    text = ''
      log="''${XDG_DATA_HOME:-$HOME/.local/share}/com.pais.handy/logs/handy.log"
      state=idle
      id=0
      stamp=$(mktemp)
      trap 'rm -f "$stamp"' EXIT

      show() { # $1 summary, $2 body
        id=$(notify-send -p -r "$id" -t 0 -u critical -a Handy \
          -h string:x-canonical-private-synchronous:handy-recording \
          -i audio-input-microphone "$1" "$2")
      }

      clear() {
        if [ "$id" != 0 ]; then
          gdbus call --session --dest org.freedesktop.Notifications \
            --object-path /org/freedesktop/Notifications \
            --method org.freedesktop.Notifications.CloseNotification "$id" >/dev/null || true
        fi
        id=0
        state=idle
      }

      # Watchdog: Handy quit or crashed while busy -> its last log line was
      # never followed by an idle one, so clear the notification ourselves.
      watchdog() {
        while sleep 2; do
          if [ "$(cat "$stamp")" != idle ] && ! pgrep -x .handy-wrapped >/dev/null; then
            echo idle >"$stamp"
          fi
        done
      }
      echo idle >"$stamp"
      watchdog &

      tail -n0 -F "$log" 2>/dev/null | while true; do
        # Poll the watchdog verdict between log lines.
        if IFS= read -r -t 1 line; then
          case "$line" in
            *"tray apply: icon=resources/recording.png"*) new=recording ;;
            *"tray apply: icon=resources/transcribing.png"*) new=transcribing ;;
            *"tray apply: icon=resources/handy.png"*) new=idle ;;
            *"tray apply: icon=unchanged"*"busy=false"*) new=idle ;;
            *) new="" ;;
          esac
        else
          new=""
          [ "$(cat "$stamp")" = idle ] && [ "$state" != idle ] && new=idle
        fi
        [ -z "$new" ] || [ "$new" = "$state" ] && continue
        echo "$new" >"$stamp"
        case "$new" in
          recording) show "Handy enregistre" "Dictée en cours. Rappuyer sur le raccourci pour arrêter." ;;
          transcribing) show "Handy transcrit" "Transcription en cours…" ;;
          idle) clear ;;
        esac
        state=$new
      done
    '';
  };

  # Keybinding entry point: if Handy is not running, `handy --toggle-transcription`
  # only launches it and the key must be pressed a second time. Start it hidden,
  # wait for its single-instance bus name, then send the toggle.
  toggle = pkgs.writeShellApplication {
    name = "handy-toggle";
    runtimeInputs = with pkgs; [
      coreutils
      procps
      systemd
      pkgs.handy
    ];
    text = ''
      if ! pgrep -x .handy-wrapped >/dev/null; then
        systemd-run --user --quiet --collect --unit="handy-$$" handy --start-hidden
        for _ in $(seq 100); do
          busctl --user status com.pais.handy.SingleInstance >/dev/null 2>&1 && break
          sleep 0.2
        done
        sleep 1
      fi
      exec handy --toggle-transcription
    '';
  };
in
{
  options.${namespace}.programs.graphical.apps.handy = {
    enable = mkBoolOpt false "Whether or not to install Handy, a speech-to-text dictation app.";
  };

  config = mkIf cfg.enable {
    home.packages = [
      pkgs.handy
      toggle
    ];

    systemd.user.services.handy-recording-indicator = {
      Unit = {
        Description = "Notification while Handy is recording";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = lib.getExe recordingIndicator;
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
