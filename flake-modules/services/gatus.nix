# Uptime checks run from outside the box they watch: gatus lives on dafpi and
# probes dafoltop's services over the LAN, through blocky and Traefik like any
# client. Importing the aspect enables it.
#
# Alerts take two routes. Home Assistant (on dafoltop) relays the usual ones;
# whatever means HA itself cannot relay — dafoltop or HA down — goes to ntfy,
# whose topic is a secret (secrets/dafpi/gatus.yaml): the repo is public.
{ inputs, ... }:
{
  flake.modules.nixos.gatus =
    { config, lib, ... }:
    let
      dafoltop = inputs.self.nixosConfigurations.dafoltop.config;
      dafoltopAddress = dafoltop.dafos.services.blocky.hostAddress;
      domain = dafoltop.dafos.services.blocky.domain;
      haWebhook = "http://${dafoltopAddress}:8123/api/webhook/${dafoltop.dafos.services.alerting.webhookId}";

      alertHA = [ { type = "custom"; } ];
      alertNtfy = [ { type = "ntfy"; } ];

      https =
        {
          name,
          subDomain,
          path,
          conditions,
          group ? "services",
          alerts ? alertHA,
        }:
        {
          inherit name group alerts;
          url = "https://${subDomain}.${domain}${path}";
          interval = "5m";
          client.insecure = false;
          conditions = conditions ++ [
            # Let's Encrypt renews at 30 days left, so under 14 means renewals fail.
            "[CERTIFICATE_EXPIRATION] > 336h"
          ];
        };

      defaultAlert = description: {
        enabled = true;
        # Three failed checks: a restart during a deploy stays quiet, a real
        # outage alerts within a few intervals.
        failure-threshold = 3;
        success-threshold = 2;
        send-on-resolved = true;
        inherit description;
      };
    in
    {
      sops.secrets."ntfy-topic".sopsFile = inputs.self + "/secrets/dafpi/gatus.yaml";
      # Shared with the hosts that push their health (health-push aspect).
      sops.secrets."health-token".sopsFile = inputs.self + "/secrets/daf/health.yaml";
      sops.templates."gatus.env" = {
        content =
          ""
          + "NTFY_TOPIC=${config.sops.placeholder."ntfy-topic"}\n"
          + "HEALTH_TOKEN=${config.sops.placeholder."health-token"}\n";
        restartUnits = [ "gatus.service" ];
      };

      services.gatus = {
        enable = true;
        openFirewall = true;
        environmentFile = config.sops.templates."gatus.env".path;

        settings = {
          web.port = 8080;

          storage = {
            type = "sqlite";
            path = "/var/lib/gatus/data.db";
          };

          alerting = {
            custom = {
              url = haWebhook;
              method = "POST";
              headers."Content-Type" = "application/json";
              body = ''{"title": "gatus : [ENDPOINT_NAME] [ALERT_TRIGGERED_OR_RESOLVED]", "message": "[ALERT_DESCRIPTION]"}'';
              placeholders.ALERT_TRIGGERED_OR_RESOLVED = {
                TRIGGERED = "en panne";
                RESOLVED = "rétabli";
              };
              default-alert = defaultAlert "injoignable depuis dafpi";
            };

            ntfy = {
              url = "https://ntfy.sh";
              # gatus interpolates ${VAR} from the environment file.
              topic = "\${NTFY_TOPIC}";
              priority = 5;
              default-alert = defaultAlert "injoignable depuis dafpi (Home Assistant ne peut pas relayer)";
            };
          };

          # Pushed by dafoltop every 5 minutes (health-push aspect): states it
          # still answers through, but nothing else alerts on. The heartbeat
          # turns a silence of 15 minutes into a failure too.
          external-endpoints =
            lib.mapAttrsToList
              (name: description: {
                inherit name;
                group = "dafoltop";
                token = "\${HEALTH_TOKEN}";
                heartbeat.interval = "15m";
                alerts = [
                  {
                    type = "custom";
                    description = "${description} (détail : http://dafpi:8080)";
                  }
                ];
              })
              {
                conteneurs = "un conteneur attendu ne tourne pas";
                stockage = "disque plein ou dock USB non monté";
                services = "un service systemd est en échec";
              };

          endpoints = [
            # dafoltop itself: if it is down, so is Home Assistant.
            {
              name = "dafoltop";
              group = "hôtes";
              url = "icmp://${dafoltopAddress}";
              interval = "1m";
              conditions = [ "[CONNECTED] == true" ];
              alerts = alertNtfy;
            }
            {
              name = "DNS primaire (blocky)";
              group = "hôtes";
              url = dafoltopAddress;
              interval = "2m";
              dns = {
                query-name = "home.${domain}";
                query-type = "A";
              };
              conditions = [
                "[DNS_RCODE] == NOERROR"
                "[BODY] == ${dafoltopAddress}"
              ];
              alerts = alertHA;
            }

            (https {
              name = "Home Assistant";
              subDomain = "home";
              path = "/manifest.json";
              conditions = [ "[STATUS] == 200" ];
              alerts = alertNtfy;
            })
            (https {
              name = "Authelia";
              subDomain = "auth";
              path = "/api/health";
              conditions = [ "[STATUS] == 200" ];
            })
            (https {
              name = "Immich";
              subDomain = "photos";
              path = "/api/server/ping";
              conditions = [
                "[STATUS] == 200"
                "[BODY].res == pong"
              ];
            })
            (https {
              name = "Jellyfin";
              subDomain = "jellyfin";
              path = "/health";
              conditions = [
                "[STATUS] == 200"
                "[BODY] == Healthy"
              ];
            })
            # Served by dafpi itself (its Traefik, through its own blocky).
            (https {
              name = "IT-Tools";
              subDomain = "it-tools";
              path = "/";
              conditions = [ "[STATUS] == 200" ];
            })
            (https {
              name = "Papra";
              subDomain = "papra";
              path = "/";
              conditions = [ "[STATUS] == 200" ];
            })
          ];
        };
      };
    };
}
