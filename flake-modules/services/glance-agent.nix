# Glance agent: this host's CPU, memory, temperature and disk usage for the
# server-stats widget of dafoltop's dashboard (Dynacat `type: remote`),
# behind this host's Traefik on the private (LAN/tailnet) gate plus a token.
# The container is not restricted, so CPU load and memory are the host's.
{ inputs, ... }:
{
  flake.modules.homeManager.glance-agent =
    {
      config,
      lib,
      osConfig,
      ...
    }:
    let
      cfg = config.dafos.services.glance-agent;
    in
    {
      options.dafos.services.glance-agent = {
        enable = lib.mkEnableOption "the Glance agent (remote server stats)";
        # Disk usage comes from statfs() on a path inside the container, so
        # mount an empty directory of each filesystem rather than the
        # filesystem itself. Keys name the path in the container; names
        # must not hold a comma or a colon (the agent's MOUNTPOINTS syntax).
        mountpoints = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                source = lib.mkOption {
                  type = lib.types.str;
                  description = "Directory on the host, on the filesystem to report.";
                };
                name = lib.mkOption {
                  type = lib.types.str;
                  description = "Label shown on the dashboard.";
                };
              };
            }
          );
          # The root (on dafpi, /home is on it too).
          default.root = {
            source = "/var/empty";
            name = "Système";
          };
          description = "Filesystems whose usage the agent reports.";
        };
      };

      config = lib.mkIf cfg.enable {
        # Also declared by the dashboard that reads it (modules/home/services/glance).
        sops.secrets."glance-agent/token".sopsFile = inputs.self + "/secrets/dafoltop/glance-agent.yaml";

        services.podman.containers.glance-agent = {
          # renovate: versioning=semver
          image = "docker.io/glanceapp/agent:v0.1.0";

          port = 27973;
          traefik = {
            name = "glance-agent";
            subDomain = "stats-${osConfig.networking.hostName}";
          };

          extraEnv.TOKEN.fromFile = config.sops.secrets."glance-agent/token".path;

          volumes = lib.mapAttrsToList (key: m: "${m.source}:/hostfs/${key}:ro") cfg.mountpoints;
          environment = {
            HIDE_MOUNTPOINTS_BY_DEFAULT = "true";
            MOUNTPOINTS = lib.concatStringsSep "," (
              lib.mapAttrsToList (key: m: "/hostfs/${key}:${m.name}") cfg.mountpoints
            );
          };
        };
      };
    };
}
