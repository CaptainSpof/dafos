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

          # Logs carry secrets (tokens in env dumps, URLs with keys), so only the
          # lldap admins get in, through Dozzle's own OIDC login against Authelia.
          # It used to trust the Remote-User header of Authelia's forwardAuth,
          # but any container on the Traefik network reaches Dozzle directly and
          # can send that header itself (checked: 401 without it, 200 with it).
          sops.secrets."dozzle/authelia/client-secret".sopsFile =
            inputs.self + "/secrets/dafoltop/dozzle.yaml";

          nps.stacks.authelia = {
            oidc.clients.dozzle = {
              client_name = "Dozzle";
              client_secret.toHash = config.sops.secrets."dozzle/authelia/client-secret".path;
              public = false;
              authorization_policy = "dozzle";
              pre_configured_consent_duration = config.nps.stacks.authelia.oidc.defaultConsentDuration;
              redirect_uris = [
                "${config.services.podman.containers.dozzle.traefik.serviceUrl}/api/auth/callback"
              ];
              scopes = [
                "openid"
                "profile"
                "email"
                "groups"
              ];
            };
            settings.identity_providers.oidc.authorization_policies.dozzle = {
              default_policy = "deny";
              rules = [
                {
                  policy = config.nps.stacks.authelia.defaultAllowPolicy;
                  subject = "group:lldap_admin";
                }
              ];
            };
          };

          # Dozzle reads roles from the `groups` claim: these two names map to its
          # `notifications` (alert rules) and `download` roles, the rest of the
          # groups mean nothing to it. Its docs warn against `groups` because there
          # every user gets in; here the authorization policy above lets admins
          # only. No `shell`/`actions`: the socket-proxy refuses them anyway.
          nps.stacks.lldap.bootstrap = {
            groups = {
              dozzle_notifications = { };
              dozzle_download = { };
            };
            users.daf.groups = [
              "dozzle_notifications"
              "dozzle_download"
            ];
          };

          services.podman.containers.dozzle = {
            # Alert rules and destinations live here (UI-only configuration).
            volumeMap.data = "${config.nps.storageBaseDir}/dozzle/data:/data";

            extraEnv.DOZZLE_AUTH_OIDC_CLIENT_SECRET.fromFile =
              config.sops.secrets."dozzle/authelia/client-secret".path;
            environment = {
              DOZZLE_AUTH_PROVIDER = "oidc";
              DOZZLE_AUTH_OIDC_ISSUER = config.nps.containers.authelia.traefik.serviceUrl;
              DOZZLE_AUTH_OIDC_CLIENT_ID = "dozzle";
              DOZZLE_AUTH_OIDC_NAME = "Authelia";
              DOZZLE_AUTH_OIDC_ROLES_CLAIM = "groups";
              DOZZLE_AUTH_OIDC_SCOPES = "groups";
              DOZZLE_HOSTNAME = osConfig.networking.hostName;
            }
            // lib.optionalAttrs (cfg.remoteAgents != [ ]) {
              DOZZLE_REMOTE_AGENT = lib.concatStringsSep "," cfg.remoteAgents;
            }
            # nps reaches this host's podman as a "remote host" (the
            # socket-proxy), which Dozzle names after the address: label it
            # with the host name instead (`url|label`).
            // lib.optionalAttrs config.nps.stacks.dozzle.useSocketProxy {
              DOZZLE_REMOTE_HOST = lib.mkForce "${config.nps.stacks.socket-proxy.address}|${osConfig.networking.hostName}";
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
