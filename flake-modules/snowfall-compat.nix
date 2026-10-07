# Phase 1 of the snowfall -> flake-parts migration: one flake-parts module
# that reproduces every output snowfall-lib's mkFlake used to generate, using
# the compatibility layer in ./_lib. New dendritic modules land as siblings of
# this file (import-tree picks up everything in flake-modules/ that doesn't
# start with an underscore); as aspects migrate out of modules/{nixos,home},
# this file and ./_lib shrink until they can be deleted.
{
  config,
  inputs,
  lib,
  ...
}:
let
  compat = import ./_lib {
    inherit inputs;
    inherit (config) systems;

    # Aspects migrated out of modules/{nixos,home}, keyed by their old path
    # there. Legacy hosts get them at that path's place in the import order;
    # add a line here when deleting a legacy module.
    migrated = {
      nixos = with config.flake.modules.nixos; {
        "home" = home;
        "nix" = nix;
        "security/sops" = sops;
        "services/avahi" = avahi;
        "services/blocky" = blocky;
        # New aspect, no legacy module behind it: the key only places it.
        "services/host-watch" = host-watch;
        "services/openssh" = openssh;
        "services/tailscale" = tailscale;
        "system/locale" = locale;
        "system/networking" = networking;
        "system/time" = time;
        "user" = user;
        "virtualisation/podman" = podman;
      };
      home = with config.flake.modules.homeManager; {
        # New aspect, no legacy module behind it: the key only places it.
        "services/dozzle" = dozzle;
        "services/health-push" = health-push;
        "user" = user;
      };
    };
  };
  src = ../.;
in
{
  systems = [
    "x86_64-linux"
    "aarch64-linux"
  ];

  flake = {
    inherit (compat.configurations) nixosConfigurations;

    lib = compat.user-lib;

    # snowfall/FUP exported the instantiated channels as `pkgs.<system>`;
    # kept for `nix repl` archaeology and parity while migrating.
    pkgs = compat.channels-by-system;

    deploy = compat.user-lib.mkDeploy {
      inherit (inputs) self;
      # Native aarch64 builds on the Pi beat qemu-user on an x86 box.
      overrides.dafpi.remoteBuild = true;
    };

    # devenv project shells: `devinit <name>`, or `nix flake init -t self#<name>`.
    templates =
      let
        templates =
          lib.mapAttrs
            (name: description: {
              inherit description;
              path = src + "/templates/${name}";
            })
            {
              devenv = "Bare devenv shell, activated by direnv";
              python = "devenv shell: Python with uv and a venv";
              node = "devenv shell: Node.js with pnpm";
              rust = "devenv shell: stable Rust toolchain";
              go = "devenv shell: Go, static builds by default";
            };
      in
      templates // { default = templates.devenv; };

    # VM boot tests for the local nps stacks, one per
    # modules/home/stacks/<name>/vm-test.nix. Kept out of `checks`: they pull
    # images, so they need `--option sandbox false`. See
    # modules/home/stacks/AGENTS.md.
    integrationTests = lib.genAttrs config.systems (
      system:
      let
        stacks =
          builtins.filter (name: builtins.pathExists (src + "/modules/home/stacks/${name}/vm-test.nix"))
            (
              builtins.attrNames (
                lib.filterAttrs (_: type: type == "directory") (builtins.readDir (src + "/modules/home/stacks"))
              )
            );
        mkTest = import (src + "/tests/integration/vm.nix") {
          inherit inputs;
          pkgs = compat.channels-by-system.${system}.nixpkgs;
        };
      in
      lib.genAttrs' stacks (name: lib.nameValuePair "${name}-integration" (mkTest name))
    );
  };

  perSystem = { system, ... }: compat.per-system system;
}
