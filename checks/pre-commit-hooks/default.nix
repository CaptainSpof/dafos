{
  inputs,
  pkgs,
  ...
}:

let
  inherit (inputs) git-hooks-nix;
in
git-hooks-nix.lib.${pkgs.stdenv.hostPlatform.system}.run {
  src = ./.;
  hooks = {
    clang-tidy.enable = true;
    luacheck.enable = true;
    pre-commit-hook-ensure-sops.enable = true;
    # Links and paths cited by AGENTS.md / skills must still exist.
    agent-links = {
      enable = true;
      name = "agent-links";
      entry = "${pkgs.python3}/bin/python3 -I .claude/bin/check-agent-links";
      files = "\\.md$";
      pass_filenames = false;
    };
    treefmt = {
      enable = true;
      settings.fail-on-change = false;
      packageOverrides.treefmt = inputs.treefmt-nix.lib.mkWrapper pkgs ../../treefmt.nix;
    };
  };
}
