# Local Ollama LLM server (CPU): dafoltop's for Home Assistant's notification
# blurbs, dafpi's for norish. See ./README.md.
{
  flake.modules.nixos.ollama =
    { config, lib, ... }:
    let
      inherit (lib) mkEnableOption mkIf mkOption types;
      opt =
        type: default: description:
        mkOption { inherit type default description; };

      cfg = config.dafos.services.ollama;
    in
    {
      options.dafos.services.ollama = {
        enable = mkEnableOption "Whether or not to enable the local Ollama LLM server";
        host = opt types.str "127.0.0.1" "Address the Ollama HTTP API listens on";
        port = opt types.port 11434 "Port the Ollama HTTP API listens on";
        models = opt (types.listOf types.str) [
          "qwen2.5:3b"
        ] "Models to pull on startup (see https://ollama.com/library)";
        keepAlive =
          opt types.str "5m"
            "How long a model stays resident in RAM after a request. Short keeps RAM free on this box; '-1' would pin it permanently.";
        openFirewallForPodman = opt types.bool false "Open `port` on `podman+` interfaces so containers can reach the API. Needs `host` to be a non-loopback address -- rootless containers reach the host via `host.containers.internal`, which never lands on 127.0.0.1.";
      };

      config = mkIf cfg.enable {

        services.ollama = {
          enable = true;
          # Default package is ollama-cpu (no cudaSupport/rocmSupport enabled),
          # which is what we want here: light, no NVIDIA driver, no Immich contention.
          inherit (cfg) host;
          inherit (cfg) port;
          loadModels = cfg.models;
        };

        # Unload the model after a short idle so it doesn't permanently hold ~3 GB
        # of RAM next to Home Assistant + Immich. Notification generation is bursty.
        services.ollama.environmentVariables.OLLAMA_KEEP_ALIVE = cfg.keepAlive;

        # Rootless podman containers (the nps stacks) reach the host through
        # `host.containers.internal`, which is forwarded to a non-loopback host
        # address -- so a 127.0.0.1 bind is unreachable from them. Mirrors the
        # `podman+` DNS rule in the podman aspect.
        networking.firewall.interfaces."podman+".allowedTCPPorts = mkIf cfg.openFirewallForPodman [
          cfg.port
        ];
      };
    };
}
