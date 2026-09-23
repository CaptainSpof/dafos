# Boots one dafos-local nps stack (modules/home/stacks/<name>) in a NixOS VM
# and checks every container unit reaches `active (running)` and stays there.
#
# Mirrors nix-podman-stacks' own tests/vm.nix and reuses its harness files
# (base-config.nix, base-home.nix, check.sh, driver.py) straight from the
# flake input, so the checks track upstream. Those files are not a public API:
# if a flake.lock bump moves them, vendor them next to this file.
{ pkgs, inputs }:
stackName:
let
  nps = inputs.nix-podman-stacks;
in
pkgs.testers.runNixOSTest {
  name = "${stackName}-integration";
  globalTimeout = 1800;

  nodes.machine =
    { config, lib, ... }:
    {
      imports = [
        (import "${nps}/tests/base-config.nix" {
          inherit (inputs) home-manager;
          inherit pkgs;
          # base-config.nix pulls `self.homeModules.nps` from this.
          self = nps;
          stackTestModule = ../../modules/home/stacks/${stackName}/vm-test.nix;
        })
      ];

      # dafos stacks read `inputs.nix-podman-stacks` in their `imports`, so it
      # has to be a special arg rather than `_module.args`.
      home-manager.extraSpecialArgs = { inherit inputs; };

      environment.etc."nps-test/expected-units".text = lib.concatStringsSep "\n" (
        map (name: "podman-${name}.service") (
          lib.attrNames config.home-manager.users.ci.services.podman.containers
        )
      );
    };

  testScript = builtins.readFile "${nps}/tests/driver.py";
}
