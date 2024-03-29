{ config, lib, pkgs, ... }:

with lib;
with lib.dafos;
let
  cfg = config.dafos.apps.kitty;
  vars = config.dafos.vars;
in
{
  imports = [ ../../../../vars.nix ];

  options.dafos.apps.kitty = with types; {
    enable = mkBoolOpt false "Whether or not to enable Kitty.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ kitty ];

    dafos.home.extraOptions = {
      programs.kitty = {
        enable = true;
        font.name = vars.font.term;
        font.size = 12;
        theme = vars.theme.dark;
        shellIntegration.enableFishIntegration = true;
        settings = {
          # Cursor
          cursor_shape = "underline";
          cursor_blink_interval = -1;
          cursor_stop_blinking_after = "15.0";

          # Scrollback
          scrollback_lines = 10000;
          scrollback_pager = "less";
          wheel_scroll_multiplier = "5.0";

          # Window
          remember_window_size = "no";
          initial_window_width = 800;
          initial_window_height = 600;
          window_border_width = 0;
          window_margin_width = 2;
          window_padding_width = 2;
          inactive_text_alpha = "1.0";
          background_opacity = "0.99";
          placement_strategy = "center";
          hide_window_decorations = "yes";
          confirm_os_window_close = 0;

          # Layouts
          enabled_layouts = "*";

          # Tabs
          tab_bar_edge = "bottom";
          tab_bar_margin_width = "0.0";
          tab_bar_min_tabs = 1;
          tab_bar_style = "powerline";
          tab_powerline_style = "slanted";
          tab_separator = " ┇ ";
          tab_title_template = "{title}{' :{}:'.format(num_windows) if num_windows > 1 else ''}";
          active_tab_font_style = "bold";
          inactive_tab_font_style = "normal";

          # Shell
          shell = "${pkgs.zellij}/bin/zellij -l compact";
        };
      };
    };
  };
}
