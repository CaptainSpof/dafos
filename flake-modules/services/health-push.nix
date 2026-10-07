# Pushes this host's health to gatus (on dafpi) as external endpoints, for the
# states nothing else alerts on while the host still answers: a container that
# stopped cleanly and never came back (nps Requires= propagation), the USB
# dock unmounted, a disk filling up, a failed unit. gatus's heartbeat also
# alerts when the pushes stop.
#
# Runs as the user (rootless podman); the matching external-endpoints and
# token live in flake-modules/services/gatus.nix.
{ inputs, ... }:
{
  flake.modules.homeManager.health-push =
    {
      config,
      lib,
      pkgs,
      osConfig ? { },
      ...
    }:
    let
      inherit (lib)
        mkEnableOption
        mkIf
        mkOption
        types
        ;

      cfg = config.dafos.services.health-push;

      # Every container this home declares is expected to be running.
      expected = builtins.attrNames config.services.podman.containers;

      push = pkgs.writeShellApplication {
        name = "health-push";
        runtimeInputs = with pkgs; [
          coreutils
          curl
          gawk
          gnugrep
          podman
          systemd
          util-linux
        ];
        text = ''
          token=$(cat ${config.sops.secrets."health-token".path})

          report() {
            local name=$1 error=$2 success=true
            [ -n "$error" ] && success=false
            curl -fsS --max-time 10 -G -X POST -o /dev/null \
              -H "Authorization: Bearer $token" \
              --data-urlencode "success=$success" \
              --data-urlencode "error=$error" \
              ${lib.escapeShellArg cfg.gatusUrl}"/api/v1/endpoints/${cfg.group}_$name/external" \
              || echo "$name: push to gatus failed" >&2
            echo "$name: ''${error:-ok}"
          }

          # Containers declared but not running.
          running=$(podman ps --format '{{.Names}}' 2>/dev/null) || running=""
          missing=""
          for c in ${lib.escapeShellArgs expected}; do
            grep -qx "$c" <<<"$running" || missing="$missing $c"
          done
          report conteneurs "''${missing:+absents :$missing}"

          # Mounts, then disk usage.
          storage=""
          for m in ${lib.escapeShellArgs cfg.mounts}; do
            findmnt -n "$m" >/dev/null || storage="$storage $m non monté;"
          done
          storage="$storage$(df -P ${lib.escapeShellArgs cfg.disks} 2>/dev/null |
            awk -v max=${toString cfg.diskThreshold} 'NR > 1 { p = $5; sub(/%/, "", p); if (p + 0 >= max) printf " %s plein à %s%%;", $6, p }' || true)"
          report stockage "$storage"

          # Failed units, system and user.
          failed=$({
            systemctl --failed --no-legend --plain
            systemctl --user --failed --no-legend --plain
          } | awk '{ printf "%s%s", sep, $1; sep = " " }' || true)
          report services "''${failed:+en échec : $failed}"
        '';
      };
    in
    {
      options.dafos.services.health-push = {
        enable = mkEnableOption "pushing this host's health to gatus";

        gatusUrl = mkOption {
          type = types.str;
          default = "http://192.168.0.15:8080";
          description = "gatus instance the external endpoints live on.";
        };
        group = mkOption {
          type = types.str;
          default = osConfig.networking.hostName or "host";
          description = "gatus group of the external endpoints (their key prefix).";
        };
        mounts = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Mount points that must be mounted.";
        };
        disks = mkOption {
          type = types.listOf types.str;
          default = [ "/" ];
          description = "Mount points whose usage is checked.";
        };
        diskThreshold = mkOption {
          type = types.ints.between 1 100;
          default = 90;
          description = "Usage (%) from which a disk is reported full.";
        };
      };

      config = mkIf cfg.enable {
        sops.secrets."health-token".sopsFile = inputs.self + "/secrets/daf/health.yaml";

        systemd.user.services.health-push = {
          Unit = {
            Description = "Push host health to gatus";
            After = [ "sops-nix.service" ];
          };
          Service = {
            Type = "oneshot";
            ExecStart = lib.getExe push;
            # Rootless podman needs the setuid newuidmap/newgidmap wrappers.
            Environment = "PATH=/run/wrappers/bin";
          };
        };

        systemd.user.timers.health-push = {
          Unit.Description = "Push host health to gatus every 5 minutes";
          Timer = {
            OnBootSec = "5min";
            OnUnitActiveSec = "5min";
          };
          Install.WantedBy = [ "timers.target" ];
        };
      };
    };
}
