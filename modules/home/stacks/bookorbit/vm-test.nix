# Boot test (see tests/integration/vm.nix). No Authelia in the VM, so the
# OIDC client is not registered.
{ dummySecretFile, ... }:
{
  imports = [ ./default.nix ];

  nps.stacks.bookorbit = {
    enable = true;
    dbPasswordFile = dummySecretFile;
    jwtSecretFile = dummySecretFile;
    setupBootstrapTokenFile = dummySecretFile;
    emailEncryptionKeyFile = dummySecretFile;
    migrationEncryptionKeyFile = dummySecretFile;
    bookRequestEncryptionKeyFile = dummySecretFile;
    oidc.registerClient = false;
  };
}
