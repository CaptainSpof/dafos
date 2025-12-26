{
  config,
  lib,
  namespace,
  ...
}:

let
  inherit (lib) mkIf types;
  inherit (lib.${namespace}) mkBoolOpt mkOpt;

  cfg = config.${namespace}.programs.terminal.emulators.wezterm;
  fontTerm = config.${namespace}.user.font.mono; # TODO
in
{
  options.${namespace}.programs.terminal.emulators.wezterm = {
    enable = mkBoolOpt false "Whether or not to enable wezterm.";
    wayland.enable = mkBoolOpt true "Whether or not to enable wayland in wezterm.";

    frontEnd = mkOpt types.str "WebGpu" "The front end to use.";
  };

  config = mkIf cfg.enable {
    programs.wezterm = {
      enable = true;
 
     extraConfig = ''
        local wezterm = require("wezterm")
        return {

          -- general
          audible_bell = "Disabled",
          check_for_updates = false,
          enable_scroll_bar = false,
          exit_behavior = "CloseOnCleanExit",
          window_close_confirmation = "NeverPrompt",
          warn_about_missing_glyphs =  false,
          term = "wezterm",
          default_prog = { "fish" },

          -- Cursor
          cursor_blink_ease_in = 'Constant',
          cursor_blink_ease_out = 'Constant',
          cursor_blink_rate = 700,
          default_cursor_style = "BlinkingUnderline",

          -- Color scheme
          color_scheme = 'Kanagawa (Gogh)',

          -- Font
          font_size = 14.0,
          font = wezterm.font_with_fallback {
            { family = '${fontTerm}', weight = "Regular" },
            { family = 'MonaspiceKr Nerd Font', weight = "Regular" },
            { family = "Symbols Nerd Font", weight = "Regular" },
            { family = 'Noto Color Emoji', weight = "Regular" },
          },

          -- Tab bar
          enable_tab_bar = true,
          hide_tab_bar_if_only_one_tab = true,
          show_tab_index_in_tab_bar = false,
          tab_bar_at_bottom = true,
          use_fancy_tab_bar = false,
          -- try and let the tabs stretch instead of squish
          tab_max_width = 10000,

          -- perf
          enable_wayland = ${if cfg.wayland.enable then "true" else "false"},
          front_end = "${cfg.frontEnd}",
          scrollback_lines = 10000,

          -- term window settings
          adjust_window_size_when_changing_font_size = false,
          inactive_pane_hsb = {
            saturation = 1.0,
            brightness = 0.8
          },
          window_background_opacity = 0.95,
          window_close_confirmation = "NeverPrompt",
          window_decorations = "NONE",
          window_padding = { left = 12, right = 12, top = 12, bottom = 12, },
        }
      '';
    };
  };
}
