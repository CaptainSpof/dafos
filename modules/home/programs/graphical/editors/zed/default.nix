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
      # Kept on Zed's PATH only: the ACP bridge and nil (same Nix server as Doom) and its formatter.
      extraPackages = with pkgs; [
        claude-agent-acp
        nil
        nixfmt
      ];
      extensions = [ "nix" ];

      userKeymaps = import ./keymap.nix;

      userSettings = {
        vim_mode = true;

        # The Nix extension prefers nixd; use nil like Doom does.
        languages.Nix.language_servers = [
          "nil"
          "!nixd"
        ];
        lsp.nil.initialization_options.formatting.command = [ "nixfmt" ];

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
