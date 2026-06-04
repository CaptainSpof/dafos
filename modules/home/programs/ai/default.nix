{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib) mkIf mkMerge;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.programs.ai;
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
    ];
  };
}
