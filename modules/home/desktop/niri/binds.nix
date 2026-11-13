{
  config,
  lib,
  firefox-pkg,
  # Mod+P opens the DMS proofreader instead of the Notepad where it is enabled.
  proofreader ? false,
}:

with config.lib.niri.actions;
let
  # binds.nix is imported without `pkgs`; the module system exposes it here.
  pkgs = config._module.args.pkgs;
  # Region select -> OCR -> clipboard; packaged in packages/screenshot-ocr so the
  # Stream Deck can run it too.
  screenshotOcr = pkgs.dafos.screenshot-ocr;
  # Toggle a dux-shell named scratchpad. dux-shell only parks and shows existing
  # windows (it never spawns), so on "empty" we run `start`, wait for a window
  # matching the jq `match` filter, park it in the pad, then show it. `onShow`
  # runs each time the pad is brought back.
  mkPad =
    {
      name,
      match,
      start,
      onShow ? "true",
      inputs,
    }:
    lib.getExe (
      pkgs.writeShellApplication {
        name = "pad-${name}";
        runtimeInputs = [
          pkgs.jq
          pkgs.niri
        ]
        ++ inputs;
        text = ''
          find_id() { niri msg -j windows | jq -r 'first(.[] | select(${match}) | .id) // empty'; }
          out=$(dms ipc call scratchpad toggle ${name})
          if [ "$out" = SCRATCHPAD_SHOWN ]; then ${onShow}; fi
          [ "$out" = SCRATCHPAD_EMPTY ] || exit 0
          id=$(find_id)
          if [ -z "$id" ]; then
            ${start}
            for _ in $(seq 100); do id=$(find_id); [ -n "$id" ] && break; sleep 0.1; done
            [ -n "$id" ] || exit 1
          fi
          niri msg action focus-window --id "$id"
          dms ipc call scratchpad move ${name}
          dms ipc call scratchpad toggle ${name}
          ${onShow}
        '';
      }
    );
  dropdownTerminal = mkPad {
    name = "dropdown";
    match = ''.app_id == "dropdown"'';
    start = "wezterm start --class dropdown >/dev/null 2>&1 &";
    inputs = [ pkgs.wezterm ];
  };
  # Vicinae's clipboard history (30 latest text entries, pinned first, newest
  # first) as plain text. Its db keeps only a 50-char preview; the full text is
  # the file clipboard-data/<offer id>. Over-size entries are skipped.
  clipboardHistory = pkgs.writeShellApplication {
    name = "vicinae-clipboard-history";
    runtimeInputs = [ pkgs.sqlite ];
    text = ''
      dir="$HOME/.local/share/vicinae"
      n=0
      hidden="''${XDG_STATE_HOME:-$HOME/.local/state}/emacs-pad/hidden-ids"
      [ -e "$hidden" ] || hidden=/dev/null
      sqlite3 -readonly -separator '|' "file:$dir/clipboard.db?mode=ro" \
        "SELECT o.id, datetime(s.updated_at,'unixepoch','localtime'), s.id
         FROM selection s JOIN data_offer o ON o.selection_id = s.id
         WHERE o.mime_type LIKE 'text/plain%' AND o.size < 20000
         GROUP BY s.id ORDER BY s.pinned_at IS NULL, s.updated_at DESC LIMIT 100" |
        while IFS='|' read -r id ts sid; do
          grep -qxF "$sid" "$hidden" && continue
          [ $((n += 1)) -le 30 ] || break
          printf '──── %s ──── %s\n' "$ts" "$sid"
          cat "$dir/clipboard-data/$id"
          printf '\n\n'
        done
    '';
  };
  # Hide one entry (selection id) from the pad's history. vicinae's db cannot be
  # written from outside (its FTS table needs a custom sqlite tokenizer), so the id
  # goes into a list the history dump skips; the entry stays in vicinae itself.
  clipboardHide = pkgs.writeShellApplication {
    name = "vicinae-clipboard-hide";
    text = ''
      case "$1" in "" | *[!0-9a-f-]*) exit 1 ;; esac
      f="''${XDG_STATE_HOME:-$HOME/.local/state}/emacs-pad/hidden-ids"
      mkdir -p "$(dirname "$f")"
      echo "$1" >>"$f"
    '';
  };
  # One emacsclient frame (title "daf-pad") laid out by `daf-pad-setup` (doom config, section daf-pad): notes,
  # clipboard history and a vterm. The clipboard buffer is refreshed on each show.
  emacsPad = mkPad {
    name = "emacs";
    match = ''.title == "daf-pad"'';
    start = "emacsclient -c -n -F '((name . \"daf-pad\"))' --eval '(progn (setq daf-pad-wl-copy \"${lib.getExe' pkgs.wl-clipboard "wl-copy"}\" daf-pad-clip-hide \"${lib.getExe clipboardHide}\") (if (fboundp (quote daf-pad-setup)) (daf-pad-setup) (message \"daf-pad: missing from the doom config\")))' >/dev/null 2>&1";
    onShow = ''f=$(mktemp); ${lib.getExe clipboardHistory} >"$f" 2>/dev/null || true; emacsclient -e "(progn (setenv \"WAYLAND_DISPLAY\" \"$WAYLAND_DISPLAY\") (daf-pad-refresh-clipboard \"$f\"))" >/dev/null 2>&1 || true; rm -f "$f"'';
    inputs = [ config.programs.emacs.finalPackage ];
  };
  dms-call = spawn "dms";
  dms-ipc = spawn "dms" "ipc";
  # spawn execs a single binary with literal args (no shell), so pipes and
  # command substitution need an explicit `sh -c`.
  shell = cmd: spawn "sh" "-c" cmd;
  # Run a niri screenshot action into a temp PNG, then open it in satty for
  # annotation. niri can't pipe a capture to stdout and its clipboard copy is
  # async/racy, so we poll the temp file until niri has written it (with a ~5s
  # safety timeout), then hand it to satty and clean up afterwards.
  shotToSatty =
    action:
    shell ''f=$(mktemp --suffix=.png); niri msg action ${action} -p false --path "$f"; for i in $(seq 100); do [ -s "$f" ] && break; sleep 0.05; done; [ -s "$f" ] && satty -f "$f"; rm -f "$f"'';
  # Binepad BNR1 knob (Vial: CW = F15, CCW = F14): its detents are too light, so
  # only every second detent in the same direction (within 1s) changes the volume.
  knobVolume =
    dir:
    shell ''f="$XDG_RUNTIME_DIR/niri-knob"; exec 9>"$f.lock"; flock 9; now=$(date +%s%N); read -r d n t 2>/dev/null < "$f"; if [ "$d" = ${dir} ] && [ "$n" = 1 ] && [ $((now - ''${t:-0})) -lt 1000000000 ]; then : > "$f"; dms ipc audio ${dir} 5; else echo "${dir} 1 $now" > "$f"; fi'';
in
lib.mkForce {
  "Mod+Q" = {
    repeat = false;
    action = close-window;
  };
  "Mod+MouseMiddle".action = close-window;
  "Mod+Shift+Slash".action = show-hotkey-overlay;
  "Mod+W".action = spawn firefox-pkg.meta.mainProgram;
  "Mod+D".action = spawn "wezterm";
  # Handy has no working global shortcut on Wayland; niri binds can't fire on
  # key release, so this toggles recording instead of push-to-hold.
  # handy-toggle starts Handy first when it is not running.
  "Mod+Shift+D" = {
    action = spawn "handy-toggle";
    hotkey-overlay.title = "Toggle Speech-to-Text (Handy)";
  };
  "Mod+E" = {
    repeat = false;
    action = spawn emacsPad;
    hotkey-overlay.title = "Toggle Emacs Pad (notes, clipboard, terminal)";
  };
  "Mod+Shift+E" = {
    repeat = false;
    action = spawn dropdownTerminal;
    hotkey-overlay.title = "Toggle Drop-down Terminal";
  };
  "Mod+M".action = spawn "dolphin";
  "Mod+Space" = {
    action = spawn "vicinae" "toggle";
    hotkey-overlay.title = "Toggle Application Launcher";
  };
  "Mod+V" = {
    repeat = false;
    action = spawn "vicinae" "deeplink" "vicinae://launch/clipboard/history?toggle=true";
    hotkey-overlay.title = "Toggle Clipboard Manager";
  };
  "Mod+B" = {
    repeat = false;
    action = spawn "vicinae" "deeplink" "vicinae://launch/@Gelei/vicinae-extension-bluetooth-0/devices";
    hotkey-overlay.title = "Bluetooth Devices";
  };
  "Mod+Shift+Comma" = {
    repeat = false;
    action = spawn "vicinae" "deeplink" "vicinae://launch/core/search-emojis";
    hotkey-overlay.title = "Emoji & Symbol Picker";
  };
  "Mod+N" = {
    action = dms-ipc "notifications" "toggle";
    hotkey-overlay.title = "Toggle Notification Center";
  };
  "Mod+P" =
    if proofreader then
      {
        action = dms-ipc "proofreader" "toggle";
        hotkey-overlay.title = "Toggle Proofreader";
      }
    else
      {
        action = dms-ipc "notepad" "toggle";
        hotkey-overlay.title = "Toggle Notepad";
      };
  "Mod+Shift+P" = {
    action = dms-call "color" "pick" "-a";
    hotkey-overlay.title = "Open Color Picker";
  };
  "Mod+X" = {
    action = dms-ipc "powermenu" "toggle";
    hotkey-overlay.title = "Toggle Power Menu";
  };
  "Mod+Delete" = {
    action = dms-ipc "processlist" "toggle";
    hotkey-overlay.title = "Toggle Process List";
  };
  "Mod+Z".action = switch-preset-column-width;
  # A single tap of the physical Super key emits F23 (via the kanata @met
  # tap-hold overload); hold/combo stays Super. So tap Super -> overview.
  # repeat = false: a held F23 must never auto-repeat the toggle.
  "F23" = {
    repeat = false;
    action = toggle-overview;
  };
  # Super + the mouse forward (front side) button also toggles the overview.
  "Mod+MouseForward".action = toggle-overview;

  "Mod+BackSpace" = {
    repeat = false;
    action = dms-ipc "lock" "lock";
  };

  "Mod+XF86AudioMute".action = dms-ipc "notifications" "toggleDoNotDisturb";

  "Mod+Return".action = maximize-window-to-edges;
  "Mod+Shift+Return".action = fullscreen-window;
  "Mod+F".action = toggle-window-floating;
  "Mod+Shift+F".action = switch-focus-between-floating-and-tiling;

  "Mod+O".action = switch-preset-column-width;

  "Mod+R".action = focus-window-or-workspace-down;
  "Mod+T".action = focus-window-or-workspace-up;
  "Mod+L".action = focus-column-or-monitor-left;
  "Mod+I".action = focus-column-or-monitor-right;

  "Mod+Shift+R".action = move-window-down-or-to-workspace-down;
  "Mod+Shift+T".action = move-window-up-or-to-workspace-up;
  "Mod+Shift+L".action = move-column-left-or-to-monitor-left;
  "Mod+Shift+I".action = move-column-right-or-to-monitor-right;

  # Jump focus straight to the adjacent monitor, regardless of columns
  # (Mod+L / Mod+I only cross monitors at the edge of a workspace).
  "Mod+Ctrl+L".action = focus-monitor-left;
  "Mod+Ctrl+I".action = focus-monitor-right;

  # Super + scroll wheel jumps between workspaces. cooldown-ms rate-limits it
  # so one notch moves one workspace instead of flying through several.
  "Mod+WheelScrollDown" = {
    cooldown-ms = 150;
    action = focus-workspace-down;
  };
  "Mod+WheelScrollUp" = {
    cooldown-ms = 150;
    action = focus-workspace-up;
  };

  # Super + wheel tilt (middle button left/right) focuses the column to that
  # side, jumping to the adjacent monitor at the edge (matches Mod+L / Mod+I).
  "Mod+WheelScrollLeft" = {
    cooldown-ms = 150;
    action = focus-column-or-monitor-left;
  };
  "Mod+WheelScrollRight" = {
    cooldown-ms = 150;
    action = focus-column-or-monitor-right;
  };

  "Mod+Comma".action = set-column-width "+15%";
  "Mod+Mod5+R".action = set-column-width "-15%";
  "Mod+G".action = set-column-width "-15%";
  "Mod+Mod5+T".action = set-column-width "+15%";

  "Mod+Alt+R".action = consume-window-into-column;
  "Mod+Alt+T".action = expel-window-from-column;

  "Mod+S".action.toggle-column-tabbed-display = { };

  # Center
  "Mod+C".action.center-column = { };
  "Mod+Alt+C".action.center-visible-columns = { };

  # Screenshots, each opened in satty for annotation:
  #   Print       region select (grim writes to stdout, satty reads stdin)
  #   Ctrl+Print  focused monitor
  #   Alt+Print   focused window
  #   Shift+Print region select -> OCR (fra+eng) -> text copied to the clipboard
  "Print".action = shell ''grim -g "$(slurp)" - | satty -f -'';
  "Ctrl+Print".action = shotToSatty "screenshot-screen";
  "Alt+Print".action = shotToSatty "screenshot-window";
  "Shift+Print".action = spawn (lib.getExe screenshotOcr);

  "XF86MonBrightnessUp" = {
    allow-when-locked = true;
    action = dms-ipc "brightness" "increment" "5" "";
  };
  "XF86MonBrightnessDown" = {
    allow-when-locked = true;
    action = dms-ipc "brightness" "decrement" "5" "";
  };

  "XF86AudioRaiseVolume" = {
    allow-when-locked = true;
    action = dms-ipc "audio" "increment" "5";
  };
  "XF86AudioLowerVolume" = {
    allow-when-locked = true;
    action = dms-ipc "audio" "decrement" "5";
  };
  "XF86AudioMute" = {
    allow-when-locked = true;
    action = dms-ipc "audio" "mute";
  };
  "XF86Launch6" = {
    allow-when-locked = true;
    action = knobVolume "increment";
  };
  "XF86Launch5" = {
    allow-when-locked = true;
    action = knobVolume "decrement";
  };
  # BNR1 knob press (Vial: F16): mutes the mic during a Discord call (Vesktop or
  # the official client), the speakers otherwise. Discord only holds a PipeWire
  # capture stream while in a voice channel.
  "XF86Launch7" = {
    allow-when-locked = true;
    action = shell ''if pw-dump | jq -e '[.[] | .info.props? // {} | select(."media.class" == "Stream/Input/Audio") | ."application.name" // "" | select(test("vesktop|discord"; "i"))] | length > 0' >/dev/null; then dms ipc audio micmute; else dms ipc audio mute; fi'';
  };
  "XF86AudioMicMute" = {
    allow-when-locked = true;
    action = dms-ipc "audio" "micmute";
  };

  "XF86AudioPlay" = {
    allow-when-locked = true;
    action = dms-ipc "mpris" "playPause";
  };
  # Bluetooth headsets send separate Play/Pause keys (AVRCP), picked from what
  # they believe the player state is; toggle on both so a stale guess still works.
  "XF86AudioPause" = {
    allow-when-locked = true;
    action = dms-ipc "mpris" "playPause";
  };
  "XF86AudioPrev" = {
    allow-when-locked = true;
    action = dms-ipc "mpris" "previous";
  };
  "XF86AudioNext" = {
    allow-when-locked = true;
    action = dms-ipc "mpris" "next";
  };
}
