[
  # Steam/Proton games (X11 via xwayland-satellite) otherwise open as tiled
  # windows: the bar stays visible and focus-follows-mouse steals keyboard
  # input. Force them to true fullscreen on open. They also open on the M27Q:
  # the game warps the cursor to the LG at launch, focus follows it, and niri
  # would otherwise open the window there.
  {
    matches = [ { app-id = "^steam_app_"; } ];
    open-fullscreen = true;
    open-on-output = "GIGA-BYTE TECHNOLOGY CO., LTD. M27Q 23250B003842";
  }
  # Games drive VRR on outputs set to "on-demand"; the desktop stays at a
  # fixed refresh rate (VRR flickers the M27Q at idle frame rates).
  {
    matches = [
      { app-id = "^steam_app_"; }
      { app-id = "^gamescope$"; }
    ];
    variable-refresh-rate = true;
  }
  {
    draw-border-with-background = false;
    geometry-corner-radius =
      let
        r = 8.0;
      in
      {
        top-left = r;
        top-right = r;
        bottom-left = r;
        bottom-right = r;
      };
    clip-to-geometry = true;
  }
  {
    matches = [
      { app-id = "^org\\.wezfurlong\\.wezterm$"; }
      { app-id = "^emacs$"; }
    ];
    # Blur whatever shows through these (translucent) terminals.
    background-effect = {
      blur = true;
    };
    default-window-height = { };
  }
  # Drop-down terminal (dropdown-terminal in binds.nix): floating, 70% of the output.
  {
    matches = [ { app-id = "^dropdown$"; } ];
    open-floating = true;
    default-column-width.proportion = 0.7;
    default-window-height.proportion = 0.7;
    background-effect = {
      blur = true;
    };
  }
  # Emacs pad (emacsPad in binds.nix): one frame with notes, clipboard, terminal.
  {
    matches = [ { title = "^daf-pad$"; } ];
    open-floating = true;
    default-column-width.proportion = 0.7;
    default-window-height.proportion = 0.7;
  }
  {
    matches = [
      { app-id = "^org\\.gnome\\.Loupe"; }
      { app-id = "^org\\.gnome\\.Nautilus"; }
      { app-id = "^org\\.gnome\\.Papers"; }
      { app-id = "^org\\.gnome\\.Calculator"; }
      { app-id = "^app\\.drey\\.Warp"; }
      { app-id = "^org\\.gnome\\.NautilusPreviewer$"; }
      { app-id = "^org\\.gnome\\.Adwaita1\\.Demo$"; }
    ];
    tiled-state = false;
    default-column-width = { };
    default-window-height = { };
  }
]
