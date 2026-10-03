{
  config,
  lib,
  namespace,
  ...
}:

let
  inherit (lib.${namespace}) mkOpt mkBoolOpt;
  inherit (lib) mkEnableOption mkIf types;

  cfg = config.${namespace}.services.languagetool;
in
{
  options.${namespace}.services.languagetool = {
    enable = mkEnableOption "the LanguageTool spelling and grammar server (backs the DMS proofreader plugin)";
    port = mkOpt types.port 8081 "Port the LanguageTool HTTP API listens on";
    heapSize =
      mkOpt types.str "1g"
        "JVM max heap (-Xmx). 512m hit OutOfMemoryError once a handful of languages had been checked: each one loads its rules and dictionary on first use.";
    openFirewallForPodman = mkBoolOpt false "Listen on every interface and open `port` on `podman+` only, so traefik can proxy it to other hosts. Off means localhost only. See README.md.";
  };

  config = mkIf cfg.enable {
    services.languagetool = {
      enable = true;
      inherit (cfg) port;
      # Upstream has no bind-address option: `public` is all interfaces or
      # nothing. The NixOS firewall keeps it off the LAN; only podman+ (where
      # traefik lives) is opened below.
      public = cfg.openFirewallForPodman;
      jvmOptions = [ "-Xmx${cfg.heapSize}" ];
    };

    networking.firewall.interfaces."podman+".allowedTCPPorts = mkIf cfg.openFirewallForPodman [
      cfg.port
    ];
  };
}
