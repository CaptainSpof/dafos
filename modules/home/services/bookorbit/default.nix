{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) mkOpt mkBoolOpt;

  cfg = config.${namespace}.services.bookorbit;

  secret = key: config.sops.secrets."bookorbit/${key}".path;
  secretsDep = [ "sops-nix.service" ];
in
{
  options.${namespace}.services.bookorbit = {
    enable = mkEnableOption "Whether or not to configure BookOrbit.";
    subDomain = mkOpt types.str "bookorbit" "The subdomain for the service.";
    expose = mkBoolOpt true ''
      Reachable from the internet (Traefik's `public` middleware chain) rather
      than from private ranges only. Matches how Grimmory is published; set it
      to `false` to keep BookOrbit LAN/tailnet-only.
    '';
  };

  config = mkIf cfg.enable {
    sops.secrets =
      lib.genAttrs
        [
          "bookorbit/db-password"
          "bookorbit/jwt-secret"
          "bookorbit/setup-bootstrap-token"
          "bookorbit/email-encryption-key"
          "bookorbit/migration-encryption-key"
          "bookorbit/book-request-encryption-key"
        ]
        (_: {
          sopsFile = lib.snowfall.fs.get-file "secrets/daf/bookorbit.yaml";
        });

    nps.stacks.bookorbit = {
      enable = true;

      dbPasswordFile = secret "db-password";
      jwtSecretFile = secret "jwt-secret";
      setupBootstrapTokenFile = secret "setup-bootstrap-token";
      emailEncryptionKeyFile = secret "email-encryption-key";
      migrationEncryptionKeyFile = secret "migration-encryption-key";
      bookRequestEncryptionKeyFile = secret "book-request-encryption-key";

      libraries = {
        root = "/mnt/bookorbit:/libraries";

        # Audiobooks stay shared: `/mnt/audio` is the Freebox CIFS share, and
        # nothing in this fleet writes to it.
        audiobooks = "/mnt/audio/Audiobooks:/audiobooks";
      };

      containers = {
        bookorbit = {
          inherit (cfg) expose;
          traefik.subDomain = cfg.subDomain;
          wants = secretsDep;
        };
        bookorbit-db.wants = secretsDep;
      };
    };
  };
}
