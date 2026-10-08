# The local nps stacks (modules/home/stacks/<name>) as `<name>-stack` aspects.
#
# The stacks stay under modules/home/stacks, where Snowfall loads them on the
# legacy hosts and the integration tests find them. A pure dendritic host
# imports the one it runs through its aspect; legacy hosts must not (it would
# be declared twice).
#
# A stack builds options from `inputs`, which Snowfall passes as a special
# arg; here it would come from `_module.args`, which depends on the config
# those options belong to (infinite recursion). Hand it the flake's.
{ inputs, lib, ... }:
let
  dir = inputs.self + "/modules/home/stacks";
  names = lib.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir));
  stack =
    name:
    let
      file = "${dir}/${name}/default.nix";
    in
    lib.setDefaultModuleLocation file (args: import file (args // { inherit inputs; }));
in
{
  flake.modules.homeManager = lib.genAttrs' names (
    name: lib.nameValuePair "${name}-stack" (stack name)
  );
}
