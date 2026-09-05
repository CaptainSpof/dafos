{
  config,
  lib,
  namespace,
  ...
}:

let
  inherit (lib.${namespace}) mkOpt mkBoolOpt;
  inherit (lib) mkEnableOption mkIf types;

  cfg = config.${namespace}.services.ollama;
in
{
  options.${namespace}.services.ollama = {
    enable = mkEnableOption "Whether or not to enable the local Ollama LLM server";
    host = mkOpt types.str "127.0.0.1" "Address the Ollama HTTP API listens on";
    port = mkOpt types.port 11434 "Port the Ollama HTTP API listens on";
    models = mkOpt (types.listOf types.str) [
      "qwen2.5:3b"
    ] "Models to pull on startup (see https://ollama.com/library)";
    keepAlive =
      mkOpt types.str "5m"
        "How long a model stays resident in RAM after a request. Short keeps RAM free on this box; '-1' would pin it permanently.";
    openFirewallForPodman = mkBoolOpt false "Open `port` on `podman+` interfaces so containers can reach the API. Needs `host` to be a non-loopback address -- rootless containers reach the host via `host.containers.internal`, which never lands on 127.0.0.1.";
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
    # `podman+` DNS rule in modules/nixos/virtualisation/podman.
    networking.firewall.interfaces."podman+".allowedTCPPorts = mkIf cfg.openFirewallForPodman [
      cfg.port
    ];
  };
}
