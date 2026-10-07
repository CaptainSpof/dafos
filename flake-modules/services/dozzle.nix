# Dozzle: live logs of the rootless podman containers, and (v10+) alerts on
# container events (die, oom, unhealthy, restart loops), configured in its UI
# and kept in /data. The nps stack already reads podman through the read-only
# socket-proxy (GET containers, events, images, info).
#
# Enabling the stack also labels every container that belongs to a stack
# (dev.dozzle.group, nps's dozzle extension), so the first deploy restarts
# them all.
{
  flake.modules.homeManager.dozzle =
    { config, lib, ... }:
    let
      cfg = config.dafos.services.dozzle;
    in
    {
      options.dafos.services.dozzle = {
        enable = lib.mkEnableOption "Dozzle, the container log viewer";
      };

      config = lib.mkIf cfg.enable {
        nps.stacks.dozzle.enable = true;

        services.podman.containers.dozzle = {
          # Alert rules and destinations live here (UI-only configuration).
          volumeMap.data = "${config.nps.storageBaseDir}/dozzle/data:/data";

          # Logs carry secrets (tokens in env dumps, URLs with keys), so only the
          # lldap admins get in. Authelia authenticates; Dozzle trusts the
          # Remote-User/-Email/-Name headers it forwards, which is safe because
          # the container is reachable only through Traefik.
          forwardAuth = {
            enable = true;
            rules = [
              {
                policy = "one_factor";
                subject = [ "group:lldap_admin" ];
              }
              { policy = "deny"; }
            ];
          };
          environment.DOZZLE_AUTH_PROVIDER = "forward-proxy";
        };
      };
    };
}
