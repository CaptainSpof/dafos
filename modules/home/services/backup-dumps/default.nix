{
  lib,
  config,
  namespace,
  pkgs,
  osConfig ? { },
  ...
}:

let
  inherit (lib) mkIf optionalAttrs;
  inherit (lib.${namespace}) mkBoolOpt mkOpt;

  cfg = config.${namespace}.services.backup-dumps;

  alerting = osConfig.${namespace}.services.alerting.enable or false;

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
  options.${namespace}.services.backup-dumps = {
    enable = mkBoolOpt false "Whether to write nightly consistent dumps of the container databases, for the restic job to pick up.";
    time =
      mkOpt lib.types.str "03:00"
        "When the dumps run. The system restic job runs half an hour later.";
  };

  config = mkIf cfg.enable {
    # Rootless containers belong to this user, so the dumps run here rather than
    # as root: root would have to `podman exec` into another user's containers.
    # The root-side restic job (modules/nixos/services/backup) reads the result.
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
}
