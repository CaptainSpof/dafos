# Dispatcharr (IPTV proxy / stream manager), as an extra container of the nps
# `streaming` stack. nix-podman-stacks does not ship it, so this adds
# `nps.stacks.streaming.dispatcharr` in the shape an upstream entry in
# `nps/modules/streaming` would take, and can be lifted there as-is.
#
# Joining the streaming stack puts it on the same network as Jellyfin, which
# reaches the M3U / EPG / HDHomeRun endpoints at `http://dispatcharr:9191`
# without going through Traefik.
{
  config,
  lib,
  inputs,
  ...
}:

let
  stackName = "streaming";
  name = "dispatcharr";

  storage = "${config.nps.storageBaseDir}/${stackName}";

  cfg = config.nps.stacks.${stackName};
in
{
  imports = import "${inputs.nix-podman-stacks}/modules/mkAliases.nix" config lib stackName [
    name
  ];

  options.nps.stacks.${stackName}.${name} = {
    enable = lib.mkEnableOption "Dispatcharr";

    uid = lib.mkOption {
      type = lib.types.ints.positive;
      default = 1000;
      description = ''
        PUID/PGID Dispatcharr runs its services and embedded PostgreSQL as.
        Unlike the other stacks this cannot follow {option}`nps.defaultUid`,
        which is 0: the entrypoint refuses to start PostgreSQL as root.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && cfg.${name}.enable) {
    services.podman.containers.${name} = {
      # Upstream publishes bare `X.Y.Z` tags (no `v`) next to the moving `latest`.
      # renovate: versioning=semver
      image = "ghcr.io/dispatcharr/dispatcharr:0.31.0";

      # All-in-one mode: PostgreSQL and Redis run inside the container and keep
      # their state under /data, so there is no sidecar and no secret to feed.
      # Its database is also why upgrades go through a rebuild rather than the
      # unattended Sunday pull.
      autoUpdate = "local";

      volumeMap.data = "${storage}/${name}:/data";

      extraEnv = {
        DISPATCHARR_ENV = "aio";
        REDIS_HOST = "localhost";
        CELERY_BROKER_URL = "redis://localhost:6379/0";
        DISPATCHARR_LOG_LEVEL = "info";
        PUID = cfg.${name}.uid;
        PGID = cfg.${name}.uid;
      };

      port = 9191;
      traefik.name = name;
      stack = stackName;
      dashboard = {
        category = "Media & Downloads";
        name = "Dispatcharr";
        description = "IPTV Management";
        icon = "di:dispatcharr";
      };
    };
  };
}
