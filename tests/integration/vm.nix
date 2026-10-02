# Boots one dafos-local nps stack (modules/home/stacks/<name>) in a NixOS VM
# and checks every container unit reaches `active (running)` and stays there.
#
# Goes through nix-podman-stacks' public `lib.mkIntegrationTest`, which owns
# the harness (base config, check script, driver). The dummy secret args the
# vm-test.nix files take (`dummySecretFile`, ...) come from upstream's
# tests/dummy-values.nix.
{ pkgs, inputs }:
stackName:
inputs.nix-podman-stacks.lib.mkIntegrationTest {
  inherit pkgs;
  name = "${stackName}-integration";
  modules = [ ../../modules/home/stacks/${stackName}/vm-test.nix ];

  # dafos stacks read `inputs.nix-podman-stacks` in their `imports`, so it
  # has to be a special arg rather than `_module.args`.
  extraSpecialArgs = {
    inherit inputs;
  }
  // import "${inputs.nix-podman-stacks}/tests/dummy-values.nix" pkgs;
}
