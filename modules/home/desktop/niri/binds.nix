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
    # Opens the Devices command of the vicinae bluetooth extension.
    # Deeplink provider is @<author>/<extension-install-dir>, which is
    # the home-manager-generated dir name (see programs.vicinae
    # extensions); the entrypoint is the command name "devices".
    action = spawn "vicinae" "deeplink" "vicinae://launch/@Gelei/vicinae-extension-bluetooth-0/devices";
    hotkey-overlay.title = "Bluetooth Devices";
  };
  "Mod+Shift+Comma" = {
    repeat = false;
    # vicinae built-in emoji & symbol picker. Provider "core" is the
    # VicinaeExtension repository id; "search-emojis" the command id.
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
  "Mod+Z".action = toggle-overview;

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

  "Print".action.screenshot = [ ];
  "Ctrl+Print".action.screenshot-screen = [ ];
  "Alt+Print".action.screenshot-window = [ ];

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

  # Media transport (driven by the kanata nav-layer media keys:
  # pp/prev/next emit XF86AudioPlay/Prev/Next). playerctl controls
  # the active MPRIS player, the same one the DMS bar reflects.
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
