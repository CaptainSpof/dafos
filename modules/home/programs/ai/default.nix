{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib) mkIf mkMerge getExe getExe';

  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.programs.ai;

  anyClaude = cfg.claude.code.enable || cfg.claude.desktop.enable;

  jq = getExe pkgs.jq;
  mcpNixos = getExe' pkgs.mcp-nixos "mcp-nixos";

  # The stdio MCP server entry, shared by every Claude client.
  nixosServer = {
    type = "stdio";
    command = mcpNixos;
    args = [ ];
  };

  # Idempotently merge an `mcpServers.<name>` entry into a JSON config that
  # the app itself manages at runtime, without clobbering anything else in it.
  registerMcp =
    name: file: server:
    let
      config' = lib.escapeShellArg file;
      serverJson = lib.escapeShellArg (builtins.toJSON server);
    in
    ''
      mkdir -p "$(dirname ${config'})"
      [ -e ${config'} ] || echo '{}' > ${config'}
      tmp=$(mktemp)
      ${jq} --argjson server ${serverJson} \
        '.mcpServers.${name} = $server' ${config'} > "$tmp" \
        && mv "$tmp" ${config'}
    '';
in
{
  options.${namespace}.programs.ai = {
    enable = mkBoolOpt false "Whether or not to enable AI tools.";

    claude.code.enable = mkBoolOpt false "Whether or not to enable Claude Code CLI.";
    claude.desktop.enable = mkBoolOpt false "Whether or not to enable Claude Desktop.";
    gemini.cli.enable = mkBoolOpt false "Whether or not to enable Gemini CLI.";
  };

  config = mkIf cfg.enable {
    home.packages = mkMerge [
      (mkIf cfg.claude.code.enable [ pkgs.claude-code ])
      (mkIf cfg.claude.desktop.enable [ pkgs.claude-desktop ])
      (mkIf cfg.gemini.cli.enable [ pkgs.gemini-cli ])
      (mkIf anyClaude [ pkgs.mcp-nixos ])
    ];

    # Register the nixos MCP server with each enabled Claude client. The config
    # files are rewritten by the apps at runtime, so we can't symlink them from
    # the store; instead we merge our entry in on activation.
    home.activation = mkMerge [
      (mkIf cfg.claude.code.enable {
        mcpNixosClaudeCode = config.lib.dag.entryAfter [ "writeBoundary" ] (
          registerMcp "nixos" "${config.home.homeDirectory}/.claude.json" nixosServer
        );
      })
      (mkIf cfg.claude.desktop.enable {
        mcpNixosClaudeDesktop = config.lib.dag.entryAfter [ "writeBoundary" ] (
          registerMcp "nixos" "${config.xdg.configHome}/Claude/claude_desktop_config.json" nixosServer
        );
      })
    ];
  };
}
