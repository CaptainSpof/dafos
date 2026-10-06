# Dendritic hosts: `configurations.nixos.<host>.module` is the whole host,
# assembled from `flake.modules.nixos.*` aspects by the files under hosts/.
# This builder adds what the snowfall compat layer injects for legacy hosts
# (upstream NixOS modules, the home-manager embedding, the FUP registry
# options), so shared aspects behave the same on both kinds of host.
{
  config,
  inputs,
  lib,
  ...
}:
{
  imports = [ inputs.flake-parts.flakeModules.modules ];

  options.configurations.nixos = lib.mkOption {
    type = lib.types.lazyAttrsOf (
      lib.types.submodule {
        options.module = lib.mkOption { type = lib.types.deferredModule; };
      }
    );
    default = { };
    description = "Dendritic NixOS hosts, built into nixosConfigurations.<name>.";
  };

  config.flake.nixosConfigurations = lib.mapAttrs (
    name:
    { module }:
    inputs.nixpkgs.lib.nixosSystem {
      modules = [
        module
        config.flake.modules.nixos.base
        { networking.hostName = lib.mkDefault name; }
      ];
    }
  ) config.configurations.nixos;

  config.flake.modules.nixos.base = {
    imports = [
      inputs.disko.nixosModules.disko
      inputs.home-manager.nixosModules.home-manager
      inputs.sops-nix.nixosModules.sops
      # nix.generateRegistryFromInputs & co., set by the nix aspect
      ./_compat/fup-options.nix
    ];

    # Only the vendored FUP module above reads it; aspects close over the
    # flake-parts `inputs` instead of taking it as a module argument.
    _module.args.inputs = inputs;

    nixpkgs.config.allowUnfree = true;

    system.configurationRevision = lib.mkIf (inputs.self ? rev) inputs.self.rev;

    home-manager.sharedModules = [
      inputs.nix-podman-stacks.homeModules.nps
      inputs.sops-nix.homeManagerModules.sops
    ];
  };
}
