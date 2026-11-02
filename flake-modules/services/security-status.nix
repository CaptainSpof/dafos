# A JSON summary of this host's intrusion defences, for the « Sécurité » page
# of the Glance dashboard (modules/home/services/glance/security.nix): CrowdSec's
# active bans and last day of alerts, whether its local and central APIs
# answer, and Authelia's failed logins and regulation bans.
#
# Runs as the user (rootless podman) every 5 minutes. The file lands in a
# directory the dashboard bind-mounts under its assets, so Dynacat reads it
# from its own port: no extra server, no extra port.
{
  flake.modules.homeManager.security-status =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib) mkEnableOption mkIf mkOption;

      cfg = config.dafos.services.security-status;

      collect = pkgs.writeShellApplication {
        name = "security-status";
        runtimeInputs = with pkgs; [
          coreutils
          gnugrep
          jq
          podman
        ];
        text = ''
          out=''${STATE_DIRECTORY:?}
          tmp=$(mktemp -d)
          trap 'rm -rf "$tmp"' EXIT

          running() {
            [ "$(podman inspect -f '{{.State.Running}}' "$1" 2>/dev/null)" = true ]
          }

          # CrowdSec. `cscli decisions list` leaves out the community
          # blocklist; that one is only counted. The alert list carries every
          # event of every alert (several MB a day), so it is cut down here.
          cs_running=false lapi=false capi=false blocklist=0
          echo '[]' >"$tmp/decisions"
          echo '[]' >"$tmp/alerts"
          if running crowdsec; then
            cs_running=true
            podman exec crowdsec cscli lapi status >/dev/null 2>&1 && lapi=true
            podman exec crowdsec cscli capi status >/dev/null 2>&1 && capi=true
            podman exec crowdsec cscli decisions list -o json >"$tmp/decisions" 2>/dev/null || echo '[]' >"$tmp/decisions"
            podman exec crowdsec cscli alerts list --since 24h -l 0 -o json 2>/dev/null |
              jq 'map({scenario, ip: .source.ip, cn: .source.cn})' >"$tmp/alerts" || echo '[]' >"$tmp/alerts"
            blocklist=$(podman exec crowdsec cscli decisions list --origin CAPI -o raw 2>/dev/null | tail -n +2 | wc -l) || blocklist=0
          fi

          # Authelia: failed first and second factor attempts over the last
          # day, and the IPs its regulation currently bans.
          au_running=false failures=0 bans=0
          if running authelia; then
            au_running=true
            failures=$(podman logs --since 24h authelia 2>&1 | grep -ci 'unsuccessful .* attempt') || failures=0
            bans=$(podman exec authelia authelia storage bans ip list 2>/dev/null |
              grep -cE '^[[:space:]]*[0-9]+[[:space:]]') || bans=0
          fi

          jq -n \
            --arg generated "$(date -Is)" \
            --argjson csRunning "$cs_running" --argjson lapi "$lapi" --argjson capi "$capi" \
            --argjson blocklist "$blocklist" \
            --argjson auRunning "$au_running" --argjson failures "$failures" --argjson bans "$bans" \
            --slurpfile decisions "$tmp/decisions" --slurpfile alerts "$tmp/alerts" '
              # "3h59m26.5s" -> "3 h 59", "12m3s" -> "12 min"
              def remaining:
                (capture("^(?:(?<h>[0-9]+)h)?(?:(?<m>[0-9]+)m)?") // {}) as $d
                | if $d.h then "\($d.h) h \($d.m // "0" | if length == 1 then "0" + . else . end)"
                  elif $d.m then "\($d.m) min"
                  else "< 1 min" end;
              def top($n): group_by(.) | map({name: .[0], count: length}) | sort_by(-.count) | .[:$n];
              {
                generated: $generated,
                crowdsec: {
                  running: $csRunning,
                  lapi: $lapi,
                  capi: $capi,
                  blocklist: $blocklist,
                  bans: [
                    $decisions[0][]
                    | . as $alert
                    | .decisions[]
                    | select(.type == "ban")
                    | {
                        ip: .value,
                        cn: ($alert.source.cn // ""),
                        as: ($alert.source.as_name // ""),
                        scenario: (.scenario | sub("^crowdsecurity/"; "")),
                        remaining: (.duration | remaining),
                        created: $alert.created_at
                      }
                  ] | sort_by(.created) | reverse,
                  alerts: ($alerts[0] | {
                    count: length,
                    ips: (map(.ip) | unique | length),
                    scenarios: (map(.scenario | sub("^crowdsecurity/"; "")) | top(6)),
                    countries: (map(.cn // "" | select(. != "")) | top(5))
                  })
                },
                authelia: {
                  running: $auRunning,
                  failures: $failures,
                  bans: $bans
                }
              }' >"$out/status.json.tmp"
          mv "$out/status.json.tmp" "$out/status.json"
        '';
      };
    in
    {
      options.dafos.services.security-status = {
        enable = mkEnableOption "a JSON summary of CrowdSec and Authelia, for the dashboard";
        dir = mkOption {
          type = lib.types.str;
          readOnly = true;
          default = "${config.xdg.stateHome}/security-status";
          description = "Directory status.json is written to (the unit's StateDirectory).";
        };
      };

      config = mkIf cfg.enable {
        # Exists before the first run, for the dashboard's bind mount.
        xdg.stateFile."security-status/.keep".text = "";

        systemd.user.services.security-status = {
          Unit.Description = "Summary of CrowdSec and Authelia for the dashboard";
          Service = {
            Type = "oneshot";
            ExecStart = lib.getExe collect;
            StateDirectory = "security-status";
            # Rootless podman needs the setuid newuidmap/newgidmap wrappers.
            Environment = "PATH=/run/wrappers/bin";
            Nice = 10;
          };
        };

        systemd.user.timers.security-status = {
          Unit.Description = "Summarise CrowdSec and Authelia every 5 minutes";
          Timer = {
            OnBootSec = "2min";
            OnUnitActiveSec = "5min";
          };
          Install.WantedBy = [ "timers.target" ];
        };
      };
    };
}
