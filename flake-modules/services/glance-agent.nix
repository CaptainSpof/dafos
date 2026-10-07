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
    {
      options.dafos.services.glance-agent.enable =
        lib.mkEnableOption "the Glance agent (remote server stats)";

      config = lib.mkIf config.dafos.services.glance-agent.enable {
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

          # Disk usage comes from statfs() on a path inside the container, so
          # mount an empty directory of each filesystem rather than the
          # filesystem itself (the root here: /home is on it too).
          volumes = [ "/var/empty:/hostfs/root:ro" ];
          environment = {
            HIDE_MOUNTPOINTS_BY_DEFAULT = "true";
            MOUNTPOINTS = "/hostfs/root:Système";
          };
        };
      };
    };
}
