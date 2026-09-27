{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.${namespace}.services.crowdsec;
in
{
  options.${namespace}.services.crowdsec = {
    enable = mkEnableOption "Whether or not to configure crowdsec.";
  };

  config = mkIf cfg.enable {
    sops.secrets."crowdsec/bouncer-key".sopsFile = lib.snowfall.fs.get-file "secrets/dafoltop/crowdsec.yaml";

    # Enabling the stack makes the traefik module collect its logs, install
    # the traefik collection and append a `crowdsec` bouncer to the `public`
    # chain; only the bouncer key has no default.
    nps.stacks = {
      crowdsec.enable = true;

      traefik = {
        crowdsec.middleware.bouncerKeyFile = config.sops.secrets."crowdsec/bouncer-key".path;

        # nps trusts RFC1918 only. The tailnet is CGNAT space, and our own
        # devices use it from outside the house, so a decision against one
        # would lock us out of the public apps too.
        dynamicConfig.http.middlewares.crowdsec.plugin.bouncer.clientTrustedIPs = [
          "100.64.0.0/10"
        ];
      };
    };

    # Both read the bouncer key into their env file at start. Without the
    # ordering, the first switch that introduced it started crowdsec 30s
    # before sops-nix had decrypted it, and the bouncer never registered.
    services.podman.containers = lib.genAttrs [ "crowdsec" "traefik" ] (_: {
      extraConfig.Unit = {
        Wants = [ "sops-nix.service" ];
        After = [ "sops-nix.service" ];
      };
    });
  };
}
