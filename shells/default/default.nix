{
  inputs,
  mkShell,
  pkgs,
  namespace,
  ...
}:

let
  # Not the `system` callPackage argument: it resolves to the deprecated
  # `pkgs.system` alias and warns.
  inherit (pkgs.stdenv.hostPlatform) system;
  pre-commit = inputs.self.checks.${system}.pre-commit-hooks;
in
mkShell {
  packages =
    with pkgs;
    [
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
    ]
    # Adds all the packages required for the pre-commit checks
    ++ pre-commit.enabledPackages;

  shellHook = ''
    ${pre-commit.shellHook}
    echo 🔨 Welcome to ${namespace}


  '';
}
