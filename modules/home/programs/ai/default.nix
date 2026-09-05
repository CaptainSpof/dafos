{
  config,
  lib,
  pkgs,
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
  mcpNixos = getExe' pkgs.mcp-nixos "mcp-nixos";

  # Cowork's virtiofsd probe only checks /usr/{libexec,bin}/virtiofsd and its
  # bundled fallback is gated to Ubuntu 22.x (claude-desktop-debian#771 — the
  # asar un-gate patch only runs in the deb build, not the nix one). Upstream's
  # fhs.nix ships no virtiofsd, so smuggle nixpkgs' Rust virtiofsd into the
  # env's /usr/bin through the qemu_kvm argument. Harmless once upstream fixes
  # it: the probe prefers the system path anyway.
  claudeDesktopFhs = pkgs.claude-desktop-fhs.override {
    qemu_kvm = pkgs.symlinkJoin {
      name = "qemu-kvm-with-virtiofsd";
      paths = [
        pkgs.qemu_kvm
        pkgs.virtiofsd
      ];
    };
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
  };

  config = mkIf cfg.enable {
    home.packages = mkMerge [
      (mkIf cfg.claude.code.enable [ pkgs.claude-code ])
      # FHS variant: Cowork's VM probe needs qemu/OVMF/virtiofsd at FHS paths,
      # which only the fhs wrapper provides. Host must also load vhost_vsock.
      (mkIf cfg.claude.desktop.enable [ claudeDesktopFhs ])
      (mkIf cfg.antigravity.cli.enable [ pkgs.antigravity-cli ])
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
