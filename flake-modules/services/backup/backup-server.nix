# A restic REST server for the other hosts' repositories, on the dock's
# backup disk. Append-only with private repos: a client can add snapshots to
# its own repository but never delete or rewrite them, so a compromised client
# cannot wipe its backups. Retention, checks and the staleness alert therefore
# run here, as the `restic` user, once a day per client.
#
# Listens on :8000 but the firewall only lets the tailnet in (tailscale0 is a
# trusted interface); clients use the server's tailnet address.
{
  flake.modules.nixos.backup-server =
    {
      lib,
      config,
      pkgs,
      ...
    }:

    let
      inherit (lib)
        concatMapStrings
        mapAttrs'
        mkEnableOption
        mkIf
        mkOption
        nameValuePair
        optionals
        types
        ;

      cfg = config.dafos.services.backup-server;
      alerting = config.dafos.services.alerting.enable or false;
      clients = lib.attrNames cfg.clients;

      maintain =
        name:
        pkgs.writeShellApplication {
          name = "backup-server-maintain-${name}";
          runtimeInputs = with pkgs; [
            coreutils
            jq
            restic
          ];
          text = ''
            export RESTIC_REPOSITORY=${lib.escapeShellArg "${cfg.dataDir}/${name}"}
            export RESTIC_PASSWORD_FILE=${config.sops.secrets."backup-server/${name}/password".path}

            # Newest snapshot first: an old one means the client stopped
            # backing up, which nothing on the client side reports.
            latest=$(restic snapshots --latest 1 --json | jq -r 'max_by(.time).time // empty')
            if [ -z "$latest" ]; then
              echo "${name}: no snapshot at all" >&2
              exit 1
            fi
            age=$(( $(date +%s) - $(date -d "$latest" +%s) ))
            if [ "$age" -gt ${toString (cfg.maxAgeHours * 3600)} ]; then
              echo "${name}: newest snapshot is $(( age / 3600 )) h old ($latest)" >&2
              exit 1
            fi

            restic forget --prune --keep-daily 7 --keep-weekly 4 --keep-monthly 6
            restic check --read-data-subset=2%
          '';
        };
    in
    {
      options.dafos.services.backup-server = {
        enable = mkEnableOption "a restic REST server for the other hosts' backups";

        dataDir = mkOption {
          type = types.str;
          default = "/mnt/backup/rest-server";
          description = "Where the client repositories live (one subdirectory per client).";
        };

        mountUnit = mkOption {
          type = types.str;
          default = "mnt-backup.mount";
          description = "The mount unit of the disk holding dataDir; starting it starts the REST server.";
        };

        maxAgeHours = mkOption {
          type = types.ints.positive;
          default = 26;
          description = "Alert when a client's newest snapshot is older than this.";
        };

        clients = mkOption {
          type = types.attrsOf (
            types.submodule {
              options.sopsFile = mkOption {
                type = types.path;
                description = "The client's sops file: restic/password (repository) and rest-server/htpasswd.";
              };
            }
          );
          default = { };
          description = "Clients, by REST user name (also their repository directory).";
        };
      };

      config = mkIf cfg.enable {
        services.restic.server = {
          enable = true;
          inherit (cfg) dataDir;
          appendOnly = true;
          privateRepos = true;
          htpasswd-file = config.sops.templates."rest-server-htpasswd".path;
        };

        sops.secrets = lib.listToAttrs (
          lib.concatMap (name: [
            (nameValuePair "backup-server/${name}/password" {
              inherit (cfg.clients.${name}) sopsFile;
              key = "restic/password";
              owner = "restic";
            })
            (nameValuePair "backup-server/${name}/htpasswd" {
              inherit (cfg.clients.${name}) sopsFile;
              key = "rest-server/htpasswd";
            })
          ]) clients
        );

        sops.templates."rest-server-htpasswd" = {
          content = concatMapStrings (
            name: "${config.sops.placeholder."backup-server/${name}/htpasswd"}\n"
          ) clients;
          owner = "restic";
          restartUnits = [ "restic-rest-server.service" ];
        };

        systemd.services = {
          # The repositories sit on the dock's backup disk: never serve (or
          # create) them on the NVMe root under an empty mount point.
          restic-rest-server = {
            unitConfig.RequiresMountsFor = [ cfg.dataDir ];
            # Requires= (from RequiresMountsFor) propagates a stop, never a start:
            # after a dock drop, or a boot where the disk came up late, the server
            # would stay down although the disk is back. Tie its start to the mount
            # instead, and not to multi-user.target (which would fail the boot
            # when the disk is absent).
            wantedBy = lib.mkForce [ cfg.mountUnit ];
          };
        }
        // mapAttrs' (
          name: _:
          nameValuePair "backup-server-maintain-${name}" {
            description = "Retention, check and staleness alert for ${name}'s backups";
            unitConfig.RequiresMountsFor = [ cfg.dataDir ];
            onFailure = optionals alerting [ "alert-failure@%n.service" ];
            serviceConfig = {
              Type = "oneshot";
              # Same owner as the files the server writes.
              User = "restic";
              Group = "restic";
              ExecStart = lib.getExe (maintain name);
              Nice = 10;
              IOSchedulingClass = "idle";
            };
          }
        ) cfg.clients;

        systemd.timers = mapAttrs' (
          name: _:
          nameValuePair "backup-server-maintain-${name}" {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              # After the clients' 03:30 runs.
              OnCalendar = "06:00";
              Persistent = true;
              RandomizedDelaySec = "10m";
            };
          }
        ) cfg.clients;
      };
    };
}
