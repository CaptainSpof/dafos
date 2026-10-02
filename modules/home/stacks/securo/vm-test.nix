# Boot test (see tests/integration/vm.nix). No Authelia in the VM, so OIDC is
# left off, and Enable Banking is off because it needs a real application.
{ dummySecretFile, ... }:
{
  imports = [ ./default.nix ];

  nps.stacks.securo = {
    enable = true;
    dbPasswordFile = dummySecretFile;
    secretKeyFile = dummySecretFile;
  };
}
