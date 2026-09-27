{
  lib,
  config,
  namespace,
  osConfig ? { },
  ...
}:

let
  inherit (lib) mkIf types filter;
  inherit (lib.${namespace}) mkOpt mkBoolOpt;

  cfg = config.${namespace}.services.alerting;

  # The stacks whose failure takes SSO or ingress down for everything else.
  watched = filter (name: config.nps.stacks.${name}.enable or false) cfg.stacks;
in
{
  options.${namespace}.services.alerting = {
    enable =
      mkBoolOpt (osConfig.${namespace}.services.alerting.enable or false)
        "Whether failed containers raise an alert. Follows the NixOS alerting module, which provides the alert-failure@ user template.";

    # host.containers.internal lands on the host over `lo`, which the
    # webhook's `local_only` accepts.
    webhookUrl = mkOpt types.str "http://host.containers.internal:8123/api/webhook/${
      osConfig.${namespace}.services.alerting.webhookId or ""
    }" "The alert webhook as reached from inside a rootless container.";

    stacks = mkOpt (types.listOf types.str) [
      "traefik"
      "authelia"
      "lldap"
    ] "nps stacks whose main container raises an alert when it ends up failed.";
  };

  config = mkIf cfg.enable {
    services.podman.containers = lib.genAttrs watched (_: {
      extraConfig.Unit.OnFailure = "alert-failure@%n.service";
    });
  };
}
