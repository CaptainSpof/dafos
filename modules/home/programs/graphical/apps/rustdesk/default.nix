{
  config,
  lib,
  namespace,
  pkgs,
  ...
}:

let
  inherit (lib) mkIf types;
  inherit (lib.${namespace}) mkBoolOpt mkOpt;

  cfg = config.${namespace}.programs.rustdesk;
in
{
  options.${namespace}.programs.rustdesk = {
    enable = mkBoolOpt false "Whether or not to install the RustDesk remote-desktop app.";

    # When enabled, this host becomes an unattended target: a session-scoped
    # agent runs, a permanent password is seeded from sops, and direct IP access
    # is turned on so it can be controlled over the tailnet (RustDesk2.toml
    # `direct-server`). Turn this off for a controller-only machine that just
    # needs the app to connect out.
    unattended.enable = mkBoolOpt true "Whether or not to run the unattended agent (controllable target).";

    direct-access-port = mkOpt types.int 21118 "Port RustDesk listens on for direct IP access.";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.rustdesk ];

    sops.secrets = mkIf cfg.unattended.enable {
      "rustdesk-password".sopsFile = lib.snowfall.fs.get-file "secrets/daf/rustdesk.yaml";
    };

    systemd.user.services.rustdesk = mkIf cfg.unattended.enable {
      Unit = {
        Description = "RustDesk unattended agent";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.rustdesk}/bin/rustdesk --service";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    home.activation.rustdeskUnattended =
      mkIf cfg.unattended.enable (config.lib.dag.entryAfter [ "sops-nix" "writeBoundary" ] ''
        cfgdir="$HOME/.config/rustdesk"
        toml="$cfgdir/RustDesk2.toml"
        secret=${lib.escapeShellArg config.sops.secrets."rustdesk-password".path}

        run mkdir -p "$cfgdir"

        # Set the permanent password without echoing it into the activation log.
        if [ -s "$secret" ]; then
          ${pkgs.rustdesk}/bin/rustdesk --password "$(cat "$secret")" >/dev/null 2>&1 || true
        fi

        # Ensure direct IP access + permanent-password auth in RustDesk2.toml.
        [ -f "$toml" ] || printf '[options]\n' > "$toml"
        grep -q '^\[options\]' "$toml" || printf '[options]\n' >> "$toml"
        grep -q "^direct-server" "$toml" \
          || ${pkgs.gnused}/bin/sed -i "/^\[options\]/a direct-server = 'Y'" "$toml"
        grep -q "^verification-method" "$toml" \
          || ${pkgs.gnused}/bin/sed -i "/^\[options\]/a verification-method = 'use-permanent-password'" "$toml"

        # Pick up the seeded config.
        run ${pkgs.systemd}/bin/systemctl --user try-restart rustdesk.service || true
      '');
  };
}
