# Ergo-L keymap for Zed's vim mode, mirroring ~/.config/doom/modules/input/ergol:
#   h j k l  ->  l r t i   (left, down, up, right)
#   displaced: j -> t (till), k -> r (replace), h -> i (insert/inner object)
#   shifted:   H L J K R T I follow the same rotation as the lowercase keys.
# Later blocks win over earlier ones in the same context, so the generic
# VimControl rotation comes first and the mode-specific fixes after it.
let
  find = {
    forward = [
      "vim::PushFindForward"
      {
        before = true;
        multiline = false;
      }
    ];
    backward = [
      "vim::PushFindBackward"
      {
        after = true;
        multiline = false;
      }
    ];
  };
  innerObject = [
    "vim::PushObject"
    { around = false; }
  ];
in
[
  # Motions, also active in Visual and Operator (VimControl covers all three).
  {
    context = "VimControl && !menu";
    bindings = {
      l = "vim::Left";
      r = "vim::Down";
      t = "vim::Up";
      i = "vim::Right";
      h = innerObject;
      j = find.forward;
      shift-j = find.backward;
      shift-l = "vim::WindowTop";
      shift-i = "vim::WindowBottom";
      # Freed by the rotation, so unbound rather than left on the old key.
      shift-h = null;
      shift-t = null;
      shift-k = null;
      shift-r = null;
    };
  }

  {
    context = "vim_mode == normal";
    bindings = {
      l = "vim::Left";
      r = "vim::Down";
      t = "vim::Up";
      i = "vim::Right";
      h = "vim::InsertBefore";
      k = "vim::PushReplace";
      shift-h = "vim::InsertFirstNonWhitespace";
      shift-i = "vim::WindowBottom";
      shift-j = find.backward;
      shift-k = "vim::ToggleReplace";
      shift-r = "vim::JoinLines";
      shift-t = "editor::Hover";
    };
  }

  {
    context = "vim_mode == visual";
    bindings = {
      i = "vim::Right";
      h = innerObject;
      k = "vim::PushReplace";
      r = "vim::Down";
      shift-h = "vim::InsertBefore";
      shift-i = "vim::WindowBottom";
      shift-j = find.backward;
      shift-k = "vim::SubstituteLine";
      shift-r = "vim::JoinLines";
    };
  }

  # evil-escape "gq"
  {
    context = "vim_mode == insert || vim_mode == replace";
    bindings."g q" = "vim::NormalBefore";
  }

  # evil-window-map: ctrl-w + the rotated keys.
  {
    context = "VimControl && !menu || !Editor && !Terminal";
    bindings = {
      "ctrl-w l" = "workspace::ActivatePaneLeft";
      "ctrl-w r" = "workspace::ActivatePaneDown";
      "ctrl-w t" = "workspace::ActivatePaneUp";
      "ctrl-w i" = "workspace::ActivatePaneRight";
      "ctrl-w shift-l" = "workspace::MovePaneLeft";
      "ctrl-w shift-r" = "workspace::MovePaneDown";
      "ctrl-w shift-t" = "workspace::MovePaneUp";
      "ctrl-w shift-i" = "workspace::MovePaneRight";
    };
  }

  # Panels: same rotation as in the editor.
  {
    context = "ProjectPanel && not_editing";
    bindings = {
      l = "project_panel::CollapseSelectedEntry";
      r = "vim::MenuSelectNext";
      t = "vim::MenuSelectPrevious";
      i = "project_panel::ExpandSelectedEntry";
      h = "project_panel::OpenPermanent";
    };
  }
  {
    context = "OutlinePanel && not_editing";
    bindings = {
      l = "outline_panel::CollapseSelectedEntry";
      r = "vim::MenuSelectNext";
      t = "vim::MenuSelectPrevious";
      i = "outline_panel::ExpandSelectedEntry";
    };
  }
  {
    context = "GitPanel && (ChangesList || HistoryList) && !GitBranchSelector && !GitRepositorySelector";
    bindings = {
      r = "menu::SelectNext";
      t = "menu::SelectPrevious";
    };
  }
  {
    context = "GitPanel && ChangesList && !GitBranchSelector && !GitRepositorySelector";
    bindings = {
      l = "git_panel::CollapseSelectedEntry";
      i = "git_panel::ExpandSelectedEntry";
      h = "git_panel::FocusEditor";
    };
  }

  # Review, Doom-style SPC leader (SPC g = git, SPC a = agent).
  {
    context = "Editor && vim_mode == normal && !menu";
    bindings = {
      "space space" = "file_finder::Toggle";
      "space e" = "project_panel::ToggleFocus";
      "space /" = "pane::DeploySearch";
      "space g g" = "git_panel::ToggleFocus";
      "space g d" = "git::Diff";
      "space g s" = "git::StageAndNext";
      "space g u" = "git::UnstageAndNext";
      "space a a" = "agent::ToggleFocus";
      "space a d" = "agent::OpenAgentDiff";
    };
  }
  # Inside the agent's diff: keep / reject hunks (alt-y, ctrl-alt-z still work).
  {
    context = "(Editor && editor_agent_diff && vim_mode == normal) || AgentDiff";
    bindings = {
      "space k" = "agent::Keep";
      "space shift-k" = "agent::KeepAll";
      "space x" = "agent::Reject";
      "space shift-x" = "agent::RejectAll";
    };
  }
]
