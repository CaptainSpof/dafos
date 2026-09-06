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
      "immich/authelia/client-secret".sopsFile = lib.snowfall.fs.get-file "secrets/daf/immich.yaml";
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
          redirect_uris = [ ];
        };

        # Home Assistant (native NixOS service, not an nps stack) — public
        # PKCE client for the hass-oidc-auth component. Access is gated on the
        # `home-assistant_user` group via the authorization policy below.
        clients.home-assistant = {
          client_name = "Home Assistant";
          public = true;
          authorization_policy = "home-assistant";
          require_pkce = true;
          pkce_challenge_method = "S256";
          pre_configured_consent_duration = config.nps.stacks.authelia.oidc.defaultConsentDuration;
          redirect_uris = [ "https://home.daftdaf.dev/auth/oidc/callback" ];
          scopes = [
            "openid"
            "profile"
            "email"
            "groups"
          ];
          claims_policy = "home-assistant";
          response_types = [ "code" ];
          grant_types = [ "authorization_code" ];
        };

        # Immich (native NixOS service, not an nps stack) — confidential client
        # mirroring what `nps.stacks.immich.oidc` registers for the containerised
        # stack. Immich has no way to refuse users that are in no group, so the
        # gating happens in the authorization policy below.
        clients.immich = {
          client_name = "Immich";
          client_secret.toHash = config.sops.secrets."immich/authelia/client-secret".path;
          public = false;
          authorization_policy = "immich";
          require_pkce = false;
          pkce_challenge_method = "";
          pre_configured_consent_duration = config.nps.stacks.authelia.oidc.defaultConsentDuration;
          redirect_uris = [
            # Both hostnames are routed to the native immich by Traefik, and
            # Immich derives its redirect uri from the origin it was opened on.
            "https://immich.daftdaf.dev/auth/login"
            "https://immich.daftdaf.dev/user-settings"
            "https://photos.daftdaf.dev/auth/login"
            "https://photos.daftdaf.dev/user-settings"
            "app.immich:///oauth-callback"
          ];
          token_endpoint_auth_method = "client_secret_post";
          scopes = [
            "openid"
            "profile"
            "email"
            "immich"
          ];
          claims_policy = "immich";
        };
      };

      containers.authelia = {
        traefik.subDomain = "auth";
        expose = true;
      };

      settings = {
        access_control.default_policy = "one_factor";
        log.level = "debug";

        # Home Assistant OIDC client: expose groups in the id_token and gate
        # access on the `home-assistant_user` group (deny-by-default).
        identity_providers.oidc = {
          claims_policies.home-assistant.id_token = [
            "email"
            "email_verified"
            "preferred_username"
            "name"
            "groups"
          ];
          authorization_policies.home-assistant = {
            default_policy = "deny";
            rules = [
              {
                policy = config.nps.stacks.authelia.defaultAllowPolicy;
                subject = [ "group:home-assistant_user" ];
              }
            ];
          };

          # Immich OIDC client: hand off the custom `immich` scope carrying the
          # role and quota claims, and gate access on the immich_{admin,user}
          # groups (deny-by-default).
          claims_policies.immich.custom_claims = {
            immich_quota.attribute = "immich_quota";
            immich_role.attribute = "immich_role";
          };
          scopes.immich.claims = [
            "immich_quota"
            "immich_role"
          ];
          authorization_policies.immich = {
            default_policy = "deny";
            rules = [
              {
                policy = config.nps.stacks.authelia.defaultAllowPolicy;
                subject = [
                  "group:immich_admin"
                  "group:immich_user"
                ];
              }
            ];
          };
        };

        # Derive the Immich role from group membership, and surface the
        # per-user quota (in GiB) stored on the LLDAP `immich-quota` attribute.
        definitions.user_attributes.immich_role.expression = ''"immich_admin" in groups ? "admin" : "user"'';
        authentication_backend.ldap.attributes.extra.immich-quota = {
          name = "immich_quota";
          value_type = "integer";
        };

        # Feeds the standard `picture` claim of the `profile` scope, which apps
        # like Immich fetch to set the user's profile image. This is a URL, not
        # the jpeg itself -- LLDAP's binary `avatar` attribute is unusable here,
        # so the lldap module serves the same file over HTTP and stores its
        # address in the `picture` attribute.
        authentication_backend.ldap.attributes.picture = "picture";
      };
    };
  };
}
