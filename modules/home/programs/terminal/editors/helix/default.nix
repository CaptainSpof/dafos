{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.programs.terminal.editors.helix;
in
{
  options.${namespace}.programs.terminal.editors.helix = {
    enable = mkBoolOpt false "Whether or not to enable helix.";
  };

  config = mkIf cfg.enable {
    programs.helix = {
      enable = true;

      settings = {
        theme = "everforest_dark";
        editor = {
          indent-guides.enable = true;

          cursor-shape = {
            insert = "bar";
            normal = "block";
            select = "underline";
          };
        };

        keys = {
          normal = {
            c = "move_char_left";
            t = "move_visual_line_down";
            s = "move_visual_line_up";
            r = "move_char_right";

            T = "join_selections";

            j = "find_till_char";
            J = "till_prev_char";
            "A-j" = "no_op";

            h = "change_selection";
            "A-h" = "change_selection_noyank";
            H = "no_op";

            l = "replace";
            L = "replace_with_yanked";

            "é" = "move_next_word_start";
            "É" = "move_next_long_word_start";

            "A-c" = "select_prev_sibling";
            "A-r" = "select_next_sibling";

            "A-t" = "copy_selection_on_next_line";
            "A-s" = "copy_selection_on_prev_line";

            k = "select_regex";
            K = "split_selection";
            "A-k" = "split_selection_on_newline";
            "A-K" = "no_op";

            w = "keep_selections";
            W = "remove_selections";

            "^" = "goto_line_start";
            "!" = "goto_line_start";
            g = {
              "l" = "no_op";
              "h" = "goto_window_center";
              "c" = "goto_line_start";
              "r" = "goto_line_end";
              "D" = "goto_reference";
              "t" = "goto_window_top";
              "s" = "goto_window_bottom";
            };

            x = "extend_to_line_bounds";
            X = "extend_line";

            "»" = "indent";
            "«" = "unindent";

            space = {
              space = "file_picker_in_current_directory";
              q = "wclose";
              Q = ":quit-all!";
              R = "no_op";
              L = "replace_selections_with_clipboard";
              "." = "file_picker_in_current_directory";
              F = "no_op";
              ":" = "file_picker";
              "«" = "buffer_picker";

              # buffers
              b = {
                "." = "buffer_picker";
                "s" = ":write";
                "S" = ":write-all";
                "q" = ":write-quit";
                "d" = ":buffer-close";
                "D" = ":buffer-close-others";
                "l" = "goto_last_accessed_file";
                "n" = "goto_next_buffer";
                "p" = "goto_previous_buffer";
              };

              # files
              f = {
                "." = "file_picker_in_current_directory";
                f = "file_picker_in_current_directory";
                ":" = "file_picker";
                c = ":config-open";
                s = ":write";
              };
            };
          };

          select = {
            c = "extend_char_left";
            t = "extend_visual_line_down";
            s = "extend_visual_line_up";
            r = "extend_char_right";

            T = "join_selections";

            j = "extend_till_char";
            J = "extend_till_prev_char";
            "A-j" = "no_op";

            h = "change_selection";
            "A-h" = "change_selection_noyank";
            H = "no_op";

            l = "replace";
            L = "replace_with_yanked";

            "é" = "extend_next_word_start";
            "É" = "extend_next_long_word_start";

            "A-c" = "select_prev_sibling";
            "A-r" = "select_next_sibling";

            "A-t" = "copy_selection_on_next_line";
            "A-s" = "copy_selection_on_prev_line";

            k = "select_regex";
            K = "split_selection";
            "A-k" = "split_selection_on_newline";
            "A-K" = "no_op";

            w = "keep_selections";
            W = "remove_selections";

            g = {
              "l" = "no_op";
              "h" = "no_op";
              "c" = "goto_line_start";
              "r" = "goto_line_end";
            };

            x = "extend_to_line_bounds";
            X = "extend_line";

            "»" = "indent";
            "«" = "unindent";
          };

          insert = {
            "A-ret" = "open_below";
          };

          insert."à" = {
            t = "normal_mode";
            s = [ ":write" ];
            q = [ ":write-quit" ];
          };
        };
      };
    };
  };
}
