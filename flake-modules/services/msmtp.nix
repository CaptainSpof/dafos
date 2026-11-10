# System `sendmail` through the Brevo SMTP relay (smtp-relay.brevo.com:587,
# STARTTLS). Anything that mails through /run/wrappers/bin/sendmail (smartd,
# cron, `echo test | sendmail -v you@example.com`) goes out from
# <hostname>@daftdaf.dev. The login and the key are sops secrets in
# secrets/dafoltop/smtp.yaml (read by dafoltop and dafpi alike); the container
# stacks (Authelia, lldap) and Immich use the same entries, see their modules.
{ inputs, ... }:
{
  flake.modules.nixos.msmtp =
    {
      config,
      lib,
      ...
    }:
    let
      inherit (lib)
        mkEnableOption
        mkIf
        mkOption
        types
        ;

      cfg = config.dafos.services.msmtp;
      host = config.networking.hostName;
      secrets = config.sops.secrets;
    in
    {
      options.dafos.services.msmtp = {
        enable = mkEnableOption "system sendmail through the Brevo SMTP relay";
        from = mkOption {
          type = types.str;
          default = "${host}@daftdaf.dev";
          description = "Envelope and header sender; any address on the Brevo-authenticated domain.";
        };
      };

      config = mkIf cfg.enable {
        sops.secrets = {
          "smtp/username".sopsFile = inputs.self + "/secrets/dafoltop/smtp.yaml";
          # Group-readable so a wheel user's `sendmail` can read the key too.
          "smtp/password" = {
            sopsFile = inputs.self + "/secrets/dafoltop/smtp.yaml";
            group = "wheel";
            mode = "0440";
          };
        };

        # msmtp has no `usereval`, so the login goes through a rendered
        # template; the key stays out of it (passwordeval reads it at send time).
        sops.templates."msmtprc" = {
          mode = "0444";
          content = ''
            defaults
            auth on
            tls on
            tls_starttls on
            tls_trust_file /etc/ssl/certs/ca-certificates.crt
            logfile -

            account brevo
            host smtp-relay.brevo.com
            port 587
            from ${cfg.from}
            user ${config.sops.placeholder."smtp/username"}
            passwordeval cat ${secrets."smtp/password".path}

            account default : brevo
          '';
        };

        programs.msmtp = {
          enable = true;
          setSendmail = true;
        };

        # Replace the file programs.msmtp generates with the rendered one.
        environment.etc."msmtprc".source = lib.mkForce config.sops.templates."msmtprc".path;
      };
    };
}
