# dafpi's nightly backup: the container database dumps (03:00, backup-dumps
# in daf's home) then restic (03:30) to dafoltop's rest-server over the
# tailnet. The repository is append-only, so retention, checks and the
# staleness alert run on dafoltop (backup-server aspect).
{ config, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  configurations.nixos.dafpi.module =
    { config, ... }:
    {
      imports = [ nixos.backup ];

      dafos.services.backup = {
        enable = true;
        # dafoltop's tailnet address: the rest-server is not reachable on the LAN.
        repository = "rest:http://100.70.68.47:8000/dafpi/";
        passwordSopsFile = ../../../secrets/dafpi/restic.yaml;
        environmentFile = config.sops.templates."restic-rest.env".path;
        prune = false;
      };

      sops.secrets."rest-server/password".sopsFile = ../../../secrets/dafpi/restic.yaml;
      sops.templates."restic-rest.env".content = ''
        RESTIC_REST_USERNAME=dafpi
        RESTIC_REST_PASSWORD=${config.sops.placeholder."rest-server/password"}
      '';
    };
}
