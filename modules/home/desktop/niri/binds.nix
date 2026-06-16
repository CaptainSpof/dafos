# niri keybindings, extracted from the niri module. Called as a function of the
# module scope: `config` provides the niri action set (config.lib.niri.actions)
# and is also used for the firefox package; `lib` for mkForce.
{
  config,
  lib,
  firefox-pkg,
}:
with config.lib.niri.actions;
let
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
  "Mod+P" = {
    action = dms-ipc "notepad" "toggle";
    hotkey-overlay.title = "Toggle Notepad";
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
  "F23".action = toggle-overview;
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
  "Print".action = shell ''grim -g "$(slurp)" - | satty -f -'';
  "Ctrl+Print".action = shotToSatty "screenshot-screen";
  "Alt+Print".action = shotToSatty "screenshot-window";

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
  "XF86AudioMicMute" = {
    allow-when-locked = true;
    action = dms-ipc "audio" "micmute";
  };

  "XF86AudioPlay" = {
    allow-when-locked = true;
    action = spawn "playerctl" "play-pause";
  };
  "XF86AudioPrev" = {
    allow-when-locked = true;
    action = spawn "playerctl" "previous";
  };
  "XF86AudioNext" = {
    allow-when-locked = true;
    action = spawn "playerctl" "next";
  };
}
