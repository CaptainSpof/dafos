{
  inputs,
  mkShell,
  pkgs,
  system,
  namespace,
  ...
}:

let
  inherit (inputs) snowfall-flake;
in
mkShell {
  packages = with pkgs; [
    hydra-check
    nix-bisect
    nix-diff
    nix-health
    nix-index
    nix-inspect
    nix-melt
    nix-prefetch-git
    nix-search-cli
    nix-tree
    nil
    nixd
    nixpkgs-hammering
    nixpkgs-lint
    snowfall-flake.packages.${system}.flake

    # Adds all the packages required for the pre-commit checks
    inputs.self.checks.${system}.pre-commit-hooks.enabledPackages
  ];

  shellHook = ''
    ${inputs.self.checks.${system}.pre-commit-hooks.shellHook}
    echo 🔨 Welcome to ${namespace}


  '';
}
