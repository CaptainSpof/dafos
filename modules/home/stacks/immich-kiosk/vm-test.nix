# Boot test (see tests/integration/vm.nix). No Immich runs in the VM: this
# only checks the kiosk image starts and stays up. It refuses to start without
# an API key, hence the dummy one.
{ pkgs, dummySecret, ... }:
{
  imports = [ ./default.nix ];

  nps.stacks.immich-kiosk = {
    enable = true;
    immichUrl = "http://immich.invalid:2283";
    environmentFiles = [
      "${pkgs.writeText "kiosk-env" "KIOSK_IMMICH_API_KEY=${dummySecret}"}"
    ];
  };
}
