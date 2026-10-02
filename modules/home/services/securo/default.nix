{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) mkOpt mkBoolOpt;

  cfg = config.${namespace}.services.securo;

  secret = key: config.sops.secrets."securo/${key}".path;
  secretsDep = [ "sops-nix.service" ];
  bankSync = cfg.enableBankingAppId != "";
in
{
  options.${namespace}.services.securo = {
    enable = mkEnableOption "Whether or not to configure Securo.";
    subDomain = mkOpt types.str "securo" "The subdomain for the service.";
    expose = mkBoolOpt false ''
      Reachable from the internet (Traefik's `public` middleware chain) rather
      than from private ranges only. Off by default: this holds bank data.
    '';
    enableBankingAppId = mkOpt types.str "" ''
      Application ID of the Enable Banking app used for PSD2 bank sync. Leave
      empty until the app is registered; the matching
      `securo/enable-banking-private-key` secret is then required.
    '';
  };

  config = mkIf cfg.enable {
    sops.secrets =
      lib.genAttrs
        (
          [
            "securo/db-password"
            "securo/secret-key"
            "securo/authelia/client-secret"
          ]
          ++ lib.optional bankSync "securo/enable-banking-private-key"
        )
        (_: {
          sopsFile = lib.snowfall.fs.get-file "secrets/dafoltop/securo.yaml";
        });

    nps.stacks.securo = {
      enable = true;

      dbPasswordFile = secret "db-password";
      secretKeyFile = secret "secret-key";

      oidc = {
        enable = true;
        clientSecretFile = secret "authelia/client-secret";
      };

      enableBanking = mkIf bankSync {
        appId = cfg.enableBankingAppId;
        privateKeyFile = secret "enable-banking-private-key";
      };

      containers = {
        securo = {
          inherit (cfg) expose;
          traefik.subDomain = cfg.subDomain;
          wants = secretsDep;
        };
        securo-backend.wants = secretsDep;
        securo-worker.wants = secretsDep;
        securo-beat.wants = secretsDep;
        securo-db.wants = secretsDep;
      };
    };
  };
}
