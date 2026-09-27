{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.${namespace}.services.docker-socket-proxy;
in
{
  options.${namespace}.services.docker-socket-proxy = {
    enable = mkEnableOption "Whether or not to put a read-only proxy in front of the podman socket.";
  };

  config = mkIf cfg.enable {
    # Traefik, glance and crowdsec mounted the raw rootless podman socket, and
    # `:ro` on a socket does not make its API read-only: whoever controlled
    # the internet-facing Traefik controlled every container daf runs. With
    # the stack on, their `useSocketProxy` defaults flip and they talk to this
    # proxy instead, which refuses anything but GETs (POST=0).
    nps.stacks.docker-socket-proxy.enable = true;

    # nps gives the proxy a Traefik router of its own (dsp.). Even read-only,
    # the API hands out every container's environment, secrets included, so
    # it must stay reachable only from the containers on its network.
    services.podman.containers.docker-socket-proxy.traefik.name = lib.mkForce null;

    # nps pins Traefik to its one bridge network with mkForce, to keep the
    # static 10.80.0.2 that podman only honours on a single network, so the
    # socket-proxy integration never gets to add its own network. Traefik then
    # cannot resolve docker-socket-proxy, loses its docker provider, and every
    # container route 404s (it did, on 2026-09-27). Nothing here uses the static
    # address -- containers reach Traefik through its network aliases -- so
    # trade it for the second network. mkOverride 40 beats nps's mkForce (50).
    services.podman.containers.traefik = {
      network = lib.mkOverride 40 [
        config.nps.stacks.traefik.network.name
        "docker-socket-proxy"
      ];
      ip4 = lib.mkForce null;
    };
  };
}
