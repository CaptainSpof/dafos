# Boot test (see tests/integration/vm.nix), with dafpi's real config.yaml. No
# Ollama in the VM: requests would fail, but the proxy must start and stay up.
{ dummySecretFile, pkgs, ... }:
{
  imports = [ ./default.nix ];

  nps.stacks.litellm = {
    enable = true;
    dbPasswordFile = dummySecretFile;
    masterKeyFile = pkgs.writeText "master-key" "sk-dummy";
    uiPasswordFile = dummySecretFile;
    settings = import ../../../../flake-modules/services/litellm/_settings.nix;
  };
}
