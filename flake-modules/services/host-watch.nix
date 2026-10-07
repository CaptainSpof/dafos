# Watches other hosts from this one and raises a Home Assistant alert when one
# stops answering. gatus runs on dafpi and cannot report its own death; this
# runs on dafoltop and covers it. Alerts go through the alerting module's HA
# webhook, which is up whenever this host is.
{
  flake.modules.nixos.host-watch =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib)
        mkEnableOption
        mkIf
        mkOption
        types
        ;

      cfg = config.dafos.services.host-watch;
      alerting = config.dafos.services.alerting;
      host = config.networking.hostName;
      threshold = toString cfg.threshold;

      watch = pkgs.writeShellApplication {
        name = "host-watch";
        runtimeInputs = with pkgs; [
          coreutils
          curl
          dig
          iputils
          jq
        ];
        text = ''
          state=''${STATE_DIRECTORY:?}

          alert() {
            if [ -n "''${HOST_WATCH_DRY_RUN:-}" ]; then
              echo "ALERT: $1 — $2"
              return
            fi
            jq -n --arg title "$1" --arg message "$2" '{title: $title, message: $message}' |
              curl -fsS --max-time 10 -X POST -H 'Content-Type: application/json' --data @- \
                ${lib.escapeShellArg "${alerting.homeAssistantUrl}/api/webhook/${alerting.webhookId}"}
          }

          check() {
            local name=$1 address=$2 dnsName=$3 ok=1 fails
            ping -c 2 -W 2 "$address" >/dev/null 2>&1 || ok=0
            if [ "$ok" = 1 ] && [ -n "$dnsName" ]; then
              [ -n "$(dig +short +time=2 +tries=2 "@$address" "$dnsName")" ] || ok=0
            fi

            fails=$(cat "$state/$name" 2>/dev/null || echo 0)
            if [ "$ok" = 1 ]; then
              if [ "$fails" -ge ${threshold} ]; then
                alert "$name : rétabli" "répond de nouveau à ${host} (après $fails vérifications en échec)"
              fi
              echo 0 >"$state/$name"
            else
              fails=$((fails + 1))
              echo "$fails" >"$state/$name"
              echo "$name ($address): check failed ($fails in a row)"
              if [ "$fails" -eq ${threshold} ]; then
                alert "$name : injoignable" "$address ne répond pas à ${host} depuis ${threshold} vérifications (1 par minute)"
              fi
            fi
          }

          ${lib.concatMapStrings (
            name:
            let
              t = cfg.targets.${name};
            in
            "check ${
              lib.escapeShellArgs [
                name
                t.address
                (if t.dnsName == null then "" else t.dnsName)
              ]
            }\n"
          ) (builtins.attrNames cfg.targets)}
        '';
      };
    in
    {
      options.dafos.services.host-watch = {
        enable = mkEnableOption "alerts when another host stops answering";

        targets = mkOption {
          type = types.attrsOf (
            types.submodule {
              options = {
                address = mkOption {
                  type = types.str;
                  description = "Address pinged every minute.";
                };
                dnsName = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Name also resolved against `address`, for a host that serves DNS.";
                };
              };
            }
          );
          default = { };
          description = "Hosts to watch, by name.";
        };

        threshold = mkOption {
          type = types.ints.positive;
          default = 3;
          description = "Consecutive failed checks (one a minute) before alerting.";
        };
      };

      config = mkIf cfg.enable {
        assertions = [
          {
            assertion = alerting.enable;
            message = "dafos.services.host-watch alerts through dafos.services.alerting, which is off.";
          }
        ];

        systemd.services.host-watch = {
          description = "Check that watched hosts still answer";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = lib.getExe watch;
            DynamicUser = true;
            StateDirectory = "host-watch";
            AmbientCapabilities = [ "CAP_NET_RAW" ];
            CapabilityBoundingSet = [ "CAP_NET_RAW" ];
            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
            ];
          };
        };

        systemd.timers.host-watch = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "3min";
            OnUnitActiveSec = "1min";
          };
        };
      };
    };
}
