# A JSON summary of the restic repositories on this host, for the « Sauvegardes »
# widget of the Glance dashboard: this host's own repository (backup aspect)
# and each rest-server client's (backup-server aspect). Per repository: the
# newest snapshot and what it added, the snapshot count, the repository size,
# and the result of the unit that last ran on it.
#
# Written by root (the repositories are root- and restic-owned 0700) after
# each of those units stops, at boot and once a day. Served read-only by static-web-server; the port stays
# closed in the firewall, glance reaches it through host.containers.internal.
{
  flake.modules.nixos.backup-status =
    {
      lib,
      config,
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

      cfg = config.dafos.services.backup-status;
      backup = config.dafos.services.backup;
      server = config.dafos.services.backup-server;
      host = config.networking.hostName;
      stateDir = "/var/lib/backup-status";

      repos =
        lib.optional (backup.enable && lib.hasPrefix "/" backup.repository) {
          name = host;
          inherit (backup) repository;
          passwordFile = config.sops.secrets."restic/password".path;
          unit = "restic-backups-local";
          # Written by backup-dumps at 03:00, before the restic run.
          dumps = "/home/${config.dafos.user.name}/backup-staging/current";
        }
        ++ lib.optionals server.enable (
          map (name: {
            inherit name;
            repository = "${server.dataDir}/${name}";
            passwordFile = config.sops.secrets."backup-server/${name}/password".path;
            # The client's own run is not visible here; retention and check are.
            unit = "backup-server-maintain-${name}";
            dumps = "";
          }) (lib.attrNames server.clients)
        );

      collect = pkgs.writeShellApplication {
        name = "backup-status";
        runtimeInputs = with pkgs; [
          coreutils
          jq
          restic
          systemd
        ];
        text = ''
          tmp=$(mktemp -d)
          trap 'rm -rf "$tmp"' EXIT

          # name repository passwordFile unit dumps
          repo() {
            local snaps="[]" stats="{}" err="" dumps=""
            if [ ! -d "$2" ]; then
              err="dépôt introuvable (disque absent ?)"
            else
              export RESTIC_REPOSITORY="$2" RESTIC_PASSWORD_FILE="$3"
              # Read-only, and never blocked by a running prune.
              if ! snaps=$(restic --no-lock snapshots --json 2>"$tmp/err") ||
                ! stats=$(restic --no-lock stats --mode raw-data --json 2>"$tmp/err"); then
                err="restic : $(tail -n 1 "$tmp/err")"
                snaps="[]" stats="{}"
              fi
            fi
            if [ -n "$5" ] && [ -e "$5" ]; then
              dumps=$(date -Is -r "$5")
            fi

            jq -n \
              --arg name "$1" --arg unit "$4" --arg err "$err" --arg dumps "$5" --arg dumpsTime "$dumps" \
              --arg result "$(systemctl show -P Result "$4")" \
              --arg state "$(systemctl show -P ActiveState "$4")" \
              --arg ran "$(systemctl show --timestamp=unix -P ExecMainExitTimestamp "$4")" \
              --argjson snaps "$snaps" --argjson stats "$stats" '
                {
                  name: $name,
                  error: $err,
                  unit: {
                    name: $unit,
                    result: $result,
                    state: $state,
                    ran: (if $ran == "" then "" else ($ran | ltrimstr("@") | tonumber | todate) end),
                  },
                  snapshots: ($snaps | length),
                  size: ($stats.total_size // 0),
                  latest: (($snaps | max_by(.time)) // {} | {time: (.time // ""), summary: (.summary // {})}),
                }
                # Only where this host dumps its databases.
                + (if $dumps == "" then {} else {dumps: {time: $dumpsTime}} end)' >"$tmp/repo-$1.json"
          }

          ${lib.concatMapStrings (r: ''
            repo ${
              lib.escapeShellArgs [
                r.name
                r.repository
                r.passwordFile
                r.unit
                r.dumps
              ]
            }
          '') repos}

          jq -s --arg generated "$(date -Is)" '{generated: $generated, repos: .}' "$tmp"/repo-*.json \
            >${stateDir}/status.json.tmp
          mv ${stateDir}/status.json.tmp ${stateDir}/status.json
        '';
      };
    in
    {
      options.dafos.services.backup-status = {
        enable = mkEnableOption "a JSON summary of this host's restic repositories, for the dashboard";
        port = mkOption {
          type = types.port;
          default = 8097;
          description = "Port the summary is served on (closed in the firewall).";
        };
      };

      config = mkIf cfg.enable {
        # static-web-server needs its root to exist before it starts.
        systemd.tmpfiles.rules = [ "d ${stateDir} 0755 root root -" ];

        services.static-web-server = {
          enable = true;
          listen = "[::]:${toString cfg.port}";
          root = stateDir;
        };

        systemd.services = {
          backup-status = {
            description = "Summary of the restic repositories for the dashboard";
            serviceConfig = {
              Type = "oneshot";
              ExecStart = lib.getExe collect;
              CacheDirectory = "backup-status";
              Environment = "RESTIC_CACHE_DIR=/var/cache/backup-status";
              Nice = 10;
              IOSchedulingClass = "idle";
            };
          };
        }
        # Refresh as soon as a run on a repository ends, whatever its result.
        # `+`: the maintain units run as the restic user.
        // lib.listToAttrs (
          map (
            r:
            lib.nameValuePair r.unit {
              serviceConfig.ExecStopPost = [
                "+${pkgs.systemd}/bin/systemctl start --no-block backup-status.service"
              ];
            }
          ) repos
        );

        systemd.timers.backup-status = {
          wantedBy = [ "timers.target" ];
          # The widget ages the snapshots itself; this only catches a disk
          # that went missing, without waking the old Samsung every few hours.
          timerConfig = {
            OnBootSec = "5min";
            OnCalendar = "12:00";
            Persistent = true;
          };
        };
      };
    };
}
