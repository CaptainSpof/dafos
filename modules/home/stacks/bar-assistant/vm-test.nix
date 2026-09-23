# Boot test (see tests/integration/vm.nix). OIDC stays off: without Authelia in
# the VM it would only exercise config, not the images.
{ lib, dummySecretFile, ... }:
{
  imports = [ ./default.nix ];

  # server + salt-rim + meilisearch + redis
  npsTests.memorySize = 3072;
  nps.stacks.bar-assistant = {
    enable = true;
    meiliMasterKeyFile = dummySecretFile;

    # No Traefik in the VM, so nps publishes each `port` on the host, and the
    # server and Salt Rim both listen on 8080.
    containers.bar-assistant-salt-rim.port = lib.mkForce "8081:8080";

    # `UserNS=keep-id:uid=33` makes podman copy the whole (large) server image
    # with shifted ownership before the first start. On a GitHub runner's VM
    # disk that took longer than the default start timeout.
    containers.bar-assistant.extraConfig.Service.TimeoutStartSec = 900;
  };
}
