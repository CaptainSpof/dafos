# Boot test (see tests/integration/vm.nix). No Immich runs in the VM: this
# only checks the kiosk image starts and stays up. It refuses to start without
# an API key, hence the dummy one.
#
# It boots with dafoltop's real config.yaml and CSS, not the defaults: kiosk
# validates its config strictly (0.44 rejected the old `show_more_info*` keys
# and crash-looped on dafoltop), so an image bump has to be checked against
# the settings it will actually run with.
{ pkgs, dummySecret, ... }:
let
  dafoltop = ../../services/immich-kiosk;
in
{
  imports = [ ./default.nix ];

  nps.stacks.immich-kiosk = {
    enable = true;
    immichUrl = "http://immich.invalid:2283";
    environmentFiles = [
      "${pkgs.writeText "kiosk-env" "KIOSK_IMMICH_API_KEY=${dummySecret}"}"
    ];

    settings = import (dafoltop + "/settings.nix");
    customCss = builtins.readFile (dafoltop + "/custom.css");
  };
}
