# Nightly consistent dumps of the rootless containers' databases (pg_dump,
# mariadb-dump, sqlite .backup) into ~/backup-staging/current, for the host's
# restic job to pick up. See the backup aspect and its README.
{
  flake.modules.homeManager.backup-dumps =
    {
      lib,
      config,
      pkgs,
      osConfig ? { },
      ...
    }:

    let
      inherit (lib)
        mkIf
        mkOption
        optionalAttrs
        types
        ;

      cfg = config.dafos.services.backup-dumps;

      alerting = osConfig.dafos.services.alerting.enable or false;

      script = pkgs.writeShellApplication {
        name = "backup-dumps";
        # `podman unshare sh -c` needs a shell of its own: this PATH is all the unit gets.
        # Missing it failed all 32 SQLite copies on the first real run.
        runtimeInputs = with pkgs; [
          bash
          podman
          sqlite
          coreutils
          findutils
          gnugrep
        ];
        text = builtins.readFile ./backup-dumps.sh;
      };
    in
    {
      options.dafos.services.backup-dumps = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to write nightly consistent dumps of the container databases, for the restic job to pick up.";
        };
        time = mkOption {
          type = types.str;
          default = "03:00";
          description = "When the dumps run. The system restic job runs half an hour later.";
        };
      };

      config = mkIf cfg.enable {
        # Rootless containers belong to this user, so the dumps run here rather than
        # as root: root would have to `podman exec` into another user's containers.
        # The root-side restic job (the backup aspect) reads the result.
        systemd.user.services.backup-dumps = {
          Unit = {
            Description = "Consistent database dumps for the restic backup";
          }
          // optionalAttrs alerting { OnFailure = "alert-failure@%n.service"; };

          Service = {
            Type = "oneshot";
            ExecStart = lib.getExe script;
            # `podman unshare` needs newuidmap/newgidmap, which live in the wrappers.
            Environment = [ "PATH=/run/wrappers/bin" ];
            TimeoutStartSec = "30min";
            Nice = 10;
            IOSchedulingClass = "idle";
          };
        };

        systemd.user.timers.backup-dumps = {
          Unit.Description = "Nightly database dumps for the restic backup";
          Timer = {
            OnCalendar = cfg.time;
            Persistent = true;
            RandomizedDelaySec = "2min";
          };
          Install.WantedBy = [ "timers.target" ];
        };
      };
    };
}
