[
  # Steam/Proton games (X11 via xwayland-satellite) otherwise open as tiled
  # windows: the bar stays visible and focus-follows-mouse steals keyboard
  # input. Force them to true fullscreen on open.
  {
    matches = [ { app-id = "^steam_app_"; } ];
    open-fullscreen = true;
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
    default-column-width = {
      proportion = 0.75;
    };
    default-window-height = { };
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
