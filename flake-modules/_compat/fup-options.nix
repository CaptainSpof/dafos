# Vendored from flake-utils-plus lib/options.nix (MIT):
# https://github.com/gytis-ivaskevicius/flake-utils-plus/blob/3542fe9126dc492e53ddd252bb0260fe035f2c0f/lib/options.nix
#
# Snowfall Lib pulled this module in through flake-utils-plus' mkFlake.
# modules/nixos/nix sets all three options, so the registry, /etc/nix/inputs
# links, and NIX_PATH generation must survive the flake-parts migration.
# `inputs` arrives via _module.args (set in _lib/default.nix, includes self).
{
  lib,
  config,
  inputs,
  ...
}:

let
  inherit (lib)
    mkIf
    filterAttrs
    mapAttrs'
    mkOption
    types
    ;
  mkFalseOption =
    description:
    mkOption {
      inherit description;
      default = false;
      example = true;
      type = types.bool;
    };

  flakes = filterAttrs (_name: value: value ? outputs) inputs;

  nixRegistry = builtins.mapAttrs (_name: v: { flake = v; }) flakes;

  cfg = config.nix;
in
{
  options = {
    nix.generateNixPathFromInputs = mkFalseOption "Generate NIX_PATH from available inputs.";
    nix.generateRegistryFromInputs = mkFalseOption "Generate Nix registry from available inputs.";
    nix.linkInputs = mkFalseOption "Symlink inputs to /etc/nix/inputs.";
  };

  config = {
    assertions = [
      {
        assertion = !cfg.generateNixPathFromInputs || cfg.linkInputs;
        message = "When using 'nix.generateNixPathFromInputs' please make sure to set 'nix.linkInputs = true'";
      }
    ];

    nix.registry =
      if cfg.generateRegistryFromInputs then nixRegistry else { self.flake = flakes.self; };

    environment.etc = mkIf (cfg.linkInputs || cfg.generateNixPathFromInputs) (
      mapAttrs' (name: value: {
        name = "nix/inputs/${name}";
        value = {
          source = value.outPath;
        };
      }) inputs
    );

    nix.nixPath = mkIf cfg.generateNixPathFromInputs [ "/etc/nix/inputs" ];
  };
}
