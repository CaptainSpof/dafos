{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) mkOpt;
  inherit (config.${namespace}.services) lldap;

  cfg = config.${namespace}.services.authelia;
in
  {

    options.${namespace}.services.authelia = {
      enable = mkEnableOption "Whether or not to configure authelia.";
      base-url = mkOpt types.str "authelia.daftdaf.dev" "The base url";
      port = mkOpt types.int 8086 "The port";
    };

    config = mkIf cfg.enable {
      sops.secrets = {
        "authelia/jwt-secret".sopsFile = lib.snowfall.fs.get-file "secrets/daf/authelia.yaml";
        "authelia/session-secret".sopsFile = lib.snowfall.fs.get-file "secrets/daf/authelia.yaml";
        "authelia/encryption-key".sopsFile = lib.snowfall.fs.get-file "secrets/daf/authelia.yaml";
        "authelia/oidc-hmac-secret".sopsFile = lib.snowfall.fs.get-file "secrets/daf/authelia.yaml";
        "authelia/oidc-rsa-pk".sopsFile = lib.snowfall.fs.get-file "secrets/daf/authelia.yaml";
        "jellyfin/authelia/client-secret".sopsFile = lib.snowfall.fs.get-file "secrets/daf/streaming.yaml";
      };

      nps.stacks.authelia = {
        enable = true;

        # ... secrets ...
        jwtSecretFile = config.sops.secrets."authelia/jwt-secret".path;
        sessionSecretFile = config.sops.secrets."authelia/session-secret".path;
        storageEncryptionKeyFile = config.sops.secrets."authelia/encryption-key".path;

        sessionProvider = "redis";

        ldap = {
          username = lldap.lldapUsers.readonly.id;
          passwordFile = lldap.lldapUsers.readonly.password_file;
        }; 

        oidc = {
          enable = true;

          hmacSecretFile = config.sops.secrets."authelia/oidc-hmac-secret".path;
          jwksRsaKeyFile = config.sops.secrets."authelia/oidc-rsa-pk".path;

          clients.dummy = {
            public = true;
            authorization_policy = "one_factor";
            redirect_uris = [];
          };
        };

        containers.authelia = {
          traefik.subDomain = "auth";
          expose = true;
        };

        settings = {
          access_control.default_policy = "one_factor";
          log.level = "debug";
        };
      };
    };
  }
