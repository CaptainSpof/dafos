{
  config,
  lib,
  pkgs,
  inputs,
  namespace,
  ...
}:

let
  inherit (lib)
    mkIf
    mkMerge
    getExe
    getExe'
    ;

  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.programs.ai;

  anyClaude = cfg.claude.code.enable || cfg.claude.desktop.enable;

  jq = getExe pkgs.jq;
  # From its own flake (see flake.nix): nixpkgs' build is broken.
  mcpNixosPkg = inputs.mcp-nixos.packages.${pkgs.stdenv.hostPlatform.system}.default;
  mcpNixos = getExe' mcpNixosPkg "mcp-nixos";

  # Journal of AI work; the global Claude rule tells the agent to call it.
  aiLog = pkgs.writeShellApplication {
    name = "ai-log";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      git
      hostname
      jq
    ];
    text = builtins.readFile ./ai-log.sh;
  };

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

  # Claude Code plugins, declared here and merged into ~/.claude/settings.json
  # (the CLI rewrites that file at runtime, so it can't be a store symlink).
  # Claude fetches and installs them itself on the next start.
  pluginMarketplaces = {
    ponytail.source = {
      source = "github";
      repo = "DietrichGebert/ponytail";
    };
  };
  enabledPlugins = {
    "ponytail@ponytail" = true;
  };

  # Idempotently merge the declared marketplaces/plugins into settings.json,
  # leaving every other key (and plugins enabled by hand) untouched.
  registerPlugins =
    let
      settings = lib.escapeShellArg "${config.home.homeDirectory}/.claude/settings.json";
    in
    ''
      mkdir -p "$(dirname ${settings})"
      [ -e ${settings} ] || echo '{}' > ${settings}
      tmp=$(mktemp)
      ${jq} \
        --argjson marketplaces ${lib.escapeShellArg (builtins.toJSON pluginMarketplaces)} \
        --argjson plugins ${lib.escapeShellArg (builtins.toJSON enabledPlugins)} \
        '.extraKnownMarketplaces += $marketplaces | .enabledPlugins += $plugins' \
        ${settings} > "$tmp" \
        && mv "$tmp" ${settings}
    '';
in
{
  # nixpkgs marked gemini-cli for removal (Google replaced it with the
  # Antigravity CLI); keep the old option name working for a while.
  imports = [
    (lib.mkRenamedOptionModule
      [ namespace "programs" "ai" "gemini" "cli" "enable" ]
      [ namespace "programs" "ai" "antigravity" "cli" "enable" ]
    )
  ];

  options.${namespace}.programs.ai = {
    enable = mkBoolOpt false "Whether or not to enable AI tools.";

    claude.code.enable = mkBoolOpt false "Whether or not to enable Claude Code CLI.";
    claude.desktop.enable = mkBoolOpt false "Whether or not to enable Claude Desktop.";
    antigravity.cli.enable = mkBoolOpt false "Whether or not to enable Antigravity CLI.";
    # Needs secrets/dafpi/litellm.yaml, which only the dafbox user key opens.
    pi.enable = mkBoolOpt false "Whether or not to enable pi, wired to dafpi's LiteLLM (local models).";
  };

  config = mkIf cfg.enable {
    home.packages = mkMerge [
      (mkIf cfg.claude.code.enable [ pkgs.claude-code ])
      # FHS variant: Cowork's VM probe needs qemu/OVMF/virtiofsd at FHS paths,
      # which only the fhs wrapper provides. Host must also load vhost_vsock.
      (mkIf cfg.claude.desktop.enable [ pkgs.claude-desktop-fhs ])
      (mkIf cfg.antigravity.cli.enable [ pkgs.antigravity-cli ])
      (mkIf anyClaude [
        mcpNixosPkg
        # Claude reaches for python3 constantly (JSON/YAML/HTTP scripting);
        # keep it small: interpreter plus the two libs it asks for.
        (pkgs.python3.withPackages (ps: [
          ps.pyyaml
          ps.requests
        ]))
      ])
      (mkIf cfg.claude.code.enable [ aiLog ])
      (mkIf cfg.pi.enable [ pkgs.pi-coding-agent ])
    ];

    # shortcut: pi uses LiteLLM's master key; mint a virtual key in LiteLLM
    # (per-client logs/limits) if anything other than daf's own pi uses it.
    sops.secrets."litellm/master-key" = mkIf cfg.pi.enable {
      sopsFile = inputs.self + "/secrets/dafpi/litellm.yaml";
    };

    # The local models behind dafpi's LiteLLM (flake-modules/services/litellm),
    # under the same names as on Ollama.
    home.file.".pi/agent/models.json" = mkIf cfg.pi.enable {
      text = builtins.toJSON {
        "$schema" = "https://pi.dev/schemas/models.schema.json";
        providers.litellm = {
          baseUrl = "https://llm.${config.dafos.user.domain}/v1";
          api = "openai-completions";
          apiKey = "!cat ${config.sops.secrets."litellm/master-key".path}";
          models = [
            # dafbox GPU, 32k context set in its Ollama.
            {
              id = "gemma4:12b";
              contextWindow = 32768;
              maxTokens = 8192;
            }
            # dafoltop CPU, Ollama's default 4k context.
            {
              id = "qwen2.5:7b";
              contextWindow = 4096;
              maxTokens = 2048;
            }
            {
              id = "qwen2.5:3b";
              contextWindow = 4096;
              maxTokens = 2048;
            }
          ];
        };
      };
    };

    # Claude Code subagent that hands a task to a local model through pi.
    home.file.".claude/agents/local-worker.md" = mkIf (cfg.pi.enable && cfg.claude.code.enable) {
      source = ./local-worker.md;
    };

    home.file.".claude/CLAUDE.md" = mkIf cfg.claude.code.enable {
      source = ./claude-global.md;
    };

    # The directory name must match the skill's `name` (icm-architect).
    home.file.".claude/skills/icm-architect" = mkIf cfg.claude.code.enable {
      source = inputs.icm-architect;
    };

    # Register the nixos MCP server with each enabled Claude client. The config
    # files are rewritten by the apps at runtime, so we can't symlink them from
    # the store; instead we merge our entry in on activation.
    home.activation = mkMerge [
      (mkIf cfg.claude.code.enable {
        mcpNixosClaudeCode = config.lib.dag.entryAfter [ "writeBoundary" ] (
          registerMcp "nixos" "${config.home.homeDirectory}/.claude.json" nixosServer
        );
        claudeCodePlugins = config.lib.dag.entryAfter [ "writeBoundary" ] registerPlugins;
      })
      (mkIf cfg.claude.desktop.enable {
        mcpNixosClaudeDesktop = config.lib.dag.entryAfter [ "writeBoundary" ] (
          registerMcp "nixos" "${config.xdg.configHome}/Claude/claude_desktop_config.json" nixosServer
        );
      })
    ];
  };
}
