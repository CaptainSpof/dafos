{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.${namespace}.services.gatus;
  alerting = config.${namespace}.services.alerting;
  base-url = config.${namespace}.services.traefik.base-url;

  # On the podman network nps aliases every routed hostname to the Traefik
  # container, so these checks cover Traefik, the certificate and the app,
  # but not public DNS or the Freebox port forward.
  endpoint = name: subDomain: path: conditions: {
    inherit name;
    group = "public";
    url = "https://${subDomain}.${base-url}${path}";
    # nps defaults to insecure; verify the chain so a broken renewal shows up.
    client.insecure = false;
    conditions = conditions ++ [
      # Let's Encrypt renews at 30 days left, so under 14 means renewals fail.
      "[CERTIFICATE_EXPIRATION] > 336h"
    ];
    alerts = mkIf alerting.enable [ { type = "custom"; } ];
  };
in
{
  options.${namespace}.services.gatus = {
    enable = mkEnableOption "Whether or not to configure gatus.";
  };

  config = mkIf cfg.enable {
    nps.stacks.gatus = {
      enable = true;

      settings = {
        endpoints = [
          (endpoint "Authelia" "auth" "/api/health" [ "[STATUS] == 200" ])
          (endpoint "Home Assistant" "home" "/manifest.json" [ "[STATUS] == 200" ])
          (endpoint "Immich" "photos" "/api/server/ping" [
            "[STATUS] == 200"
            "[BODY].res == pong"
          ])
          (endpoint "Jellyfin" "jellyfin" "/health" [
            "[STATUS] == 200"
            "[BODY] == Healthy"
          ])
        ];

        alerting.custom = mkIf alerting.enable {
          url = alerting.webhookUrl;
          method = "POST";
          headers."Content-Type" = "application/json";
          body = ''{"title": "gatus : [ENDPOINT_NAME] [ALERT_TRIGGERED_OR_RESOLVED]", "message": "[ALERT_DESCRIPTION]"}'';
          placeholders.ALERT_TRIGGERED_OR_RESOLVED = {
            TRIGGERED = "en panne";
            RESOLVED = "rétabli";
          };
          default-alert = {
            enabled = true;
            # Three failed 5-minute checks: a Traefik or HA restart during a
            # deploy stays quiet, a real outage alerts within ~15 minutes.
            failure-threshold = 3;
            success-threshold = 2;
            send-on-resolved = true;
            description = "injoignable depuis l'extérieur";
          };
        };
      };
    };
  };
}
