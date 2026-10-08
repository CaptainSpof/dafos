# Dozzle: live logs of the rootless podman containers, and (v10+) alerts on
# container events (die, oom, unhealthy, restart loops), configured in its UI
# and kept in /data. The nps stack already reads podman through the read-only
# socket-proxy (GET containers, events, images, info).
#
# Enabling the stack also labels every container that belongs to a stack
# (dev.dozzle.group, nps's dozzle extension), so the first deploy restarts
# them all.
#
# Other hosts run a Dozzle agent (`agent.enable`) that the hub (`remoteAgents`)
# connects to, so one UI shows every host. Whoever reaches an agent's port can
# read every log and run commands in the containers (the agent ignores the
# actions/shell switches), hence three locks: a certificate pair of our own
# (Dozzle's built-in one is the same in every install), the agent reading
# podman through the read-only socket-proxy only, and the port opened to the
# hub's address alone (the host's firewall, see the agent host).
{ inputs, ... }:
{
  flake.modules.homeManager.dozzle =
    {
      config,
      lib,
      osConfig,
      ...
    }:
    let
      inherit (lib)
        mkEnableOption
        mkIf
        mkOption
        types
        ;

      cfg = config.dafos.services.dozzle;

      certs = [
        "${config.sops.secrets."dozzle-agent/cert".path}:/dozzle_cert.pem:ro"
        "${config.sops.secrets."dozzle-agent/key".path}:/dozzle_key.pem:ro"
      ];
    in
    {
      options.dafos.services.dozzle = {
        enable = mkEnableOption "Dozzle, the container log viewer";

        remoteAgents = mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [ "192.168.0.15:7007" ];
          description = "Dozzle agents (host:port) this hub shows next to its own containers.";
        };

        agent = {
          enable = mkEnableOption "a Dozzle agent, for another host's Dozzle hub";
          port = mkOption {
            type = types.port;
            default = 7007;
            description = "Port the agent listens on (published on the host).";
          };
        };
      };

      config = lib.mkMerge [
        (mkIf (cfg.remoteAgents != [ ] || cfg.agent.enable) {
          # Shared by the hub and its agents (servers' sops rule).
          sops.secrets = lib.genAttrs [ "dozzle-agent/cert" "dozzle-agent/key" ] (_: {
            sopsFile = inputs.self + "/secrets/dafoltop/dozzle-agent.yaml";
          });
        })

        (mkIf cfg.enable {
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
            environment = {
              DOZZLE_AUTH_PROVIDER = "forward-proxy";
              DOZZLE_HOSTNAME = osConfig.networking.hostName;
            }
            // lib.optionalAttrs (cfg.remoteAgents != [ ]) {
              DOZZLE_REMOTE_AGENT = lib.concatStringsSep "," cfg.remoteAgents;
            };
            volumes = mkIf (cfg.remoteAgents != [ ]) certs;
          };
        })

        (mkIf cfg.agent.enable {
          services.podman.containers.dozzle-agent = {
            # The hub's version: nps's dozzle stack pins it.
            image = "docker.io/amir20/dozzle:v11.3.0";
            exec = "agent";
            ports = [ "${toString cfg.agent.port}:7007" ];
            volumes = certs;
            environment = {
              DOCKER_HOST = config.nps.stacks.socket-proxy.address;
              DOZZLE_HOSTNAME = osConfig.networking.hostName;
            };
            # What the hub itself gets (nps's dozzle module): read-only, and
            # no exec, so the agent cannot run commands whatever it is asked.
            # Plus the API handshake its Docker client does first (HEAD then
            # GET /_ping, /version), which the hub's remote-host mode skips: the
            # proxy refused it and the agent exited "Forbidden".
            socketProxyPermissions = with config.nps.stacks.socket-proxy.sections; {
              GET = [
                containers
                images
                info
                events
                ping
                version
              ];
              HEAD = [ ping ];
            };
          };
        })
      ];
    };
}
