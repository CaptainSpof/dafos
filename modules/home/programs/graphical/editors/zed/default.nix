{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib) mkIf getExe;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.programs.graphical.editors.zed;
in
{
  options.${namespace}.programs.graphical.editors.zed = {
    enable = mkBoolOpt false "Whether or not to enable the Zed editor.";
  };

  config = mkIf cfg.enable {
    programs.zed-editor = {
      enable = true;
      # ACP bridge, kept on Zed's PATH only.
      extraPackages = [ pkgs.claude-agent-acp ];

      userKeymaps = import ./keymap.nix;

      userSettings = {
        vim_mode = true;

        # Claude Code over ACP: the bridge reuses the existing `claude` login
        # (subscription), so no key lives in this file.
        agent_servers."Claude Code" = {
          type = "custom";
          command = getExe pkgs.claude-agent-acp;
          args = [ ];
        };

        # Ollama on dafbox itself (ROCm GPU). No key: the API is unauthenticated.
        language_models.ollama = {
          api_url = "http://127.0.0.1:11434";
          available_models = [
            {
              name = "gemma4:12b";
              display_name = "Gemma 4 12B (dafbox)";
              max_tokens = 32768; # matches OLLAMA_CONTEXT_LENGTH on dafbox
            }
          ];
        };
      };
    };
  };
}
