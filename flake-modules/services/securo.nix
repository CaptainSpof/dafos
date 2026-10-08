# Securo (local nps stack, modules/home/stacks/securo): personal finances,
# OIDC through Authelia, private (bank data). Runs on dafpi: its OIDC client
# and lldap group are served by dafoltop's Authelia/lldap through
# authelia-peers. A pure dendritic host also imports `securo-stack`
# (./local-stacks.nix).
{ inputs, ... }:
{
  flake.modules.homeManager.securo =
    { config, lib, ... }:
    let
      inherit (lib)
        mkEnableOption
        mkIf
        mkOption
        types
        ;

      cfg = config.dafos.services.securo;

      secret = key: config.sops.secrets."securo/${key}".path;
      secretsDep = [ "sops-nix.service" ];
      bankSync = cfg.enableBankingAppId != "";
    in
    {
      options.dafos.services.securo = {
        enable = mkEnableOption "Whether or not to configure Securo.";
        subDomain = mkOption {
          type = types.str;
          default = "securo";
          description = "The subdomain for the service.";
        };
        expose = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Reachable from the internet (Traefik's `public` middleware chain) rather
            than from private ranges only. Off by default: this holds bank data.
          '';
        };
        enableBankingAppId = mkOption {
          type = types.str;
          default = "";
          description = ''
            Application ID of the Enable Banking app used for PSD2 bank sync. Leave
            empty until the app is registered; the matching
            `securo/enable-banking-private-key` secret is then required.
          '';
        };
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
              sopsFile = inputs.self + "/secrets/dafoltop/securo.yaml";
            });

        nps.stacks.securo = {
          enable = true;

          dbPasswordFile = secret "db-password";
          secretKeyFile = secret "secret-key";

          oidc = {
            enable = true;
            clientSecretFile = secret "authelia/client-secret";
            # Authelia is a peer's where this host runs none.
            issuerUrl = mkIf (
              !config.nps.stacks.authelia.enable
            ) "https://auth.${config.nps.stacks.traefik.domain}";
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
    };
}
