# LiteLLM (local nps stack, modules/home/stacks/litellm) on dafpi: the
# llm.daftdaf.dev OpenAI-compatible endpoint the Kobo's X-Ray plugin calls,
# relaying to dafbox's Ollama and logging every request (UI: /ui). Private
# gate (LAN/tailnet); the API needs a LiteLLM key. The UI signs in through
# Authelia (LiteLLM's generic SSO, free up to 5 users), the admin password
# staying as the /fallback/login. The client and its `litellm_user` lldap
# group are served by dafoltop's Authelia/lldap through authelia-peers, so
# a change here needs a dafoltop deploy too.
# A pure dendritic host also imports `litellm-stack` (../local-stacks.nix).
{ inputs, ... }:
{
  flake.modules.homeManager.litellm =
    { config, lib, ... }:
    let
      cfg = config.dafos.services.litellm;
      secret = key: config.sops.secrets."litellm/${key}".path;
      secretsDep = [ "sops-nix.service" ];

      autheliaUrl = "https://auth.${config.nps.stacks.traefik.domain}";
      serviceUrl = config.services.podman.containers.litellm.traefik.serviceUrl;
      oidcSecret = config.sops.secrets."litellm/authelia/client-secret".path;
      userGroup = "litellm_user";
    in
    {
      options.dafos.services.litellm = {
        enable = lib.mkEnableOption "Whether or not to configure LiteLLM.";
        subDomain = lib.mkOption {
          type = lib.types.str;
          default = "llm";
          description = "The subdomain for the service.";
        };
      };

      config = lib.mkIf cfg.enable {
        sops.secrets =
          lib.genAttrs
            [
              "litellm/db-password"
              "litellm/master-key"
            ]
            (_: {
              sopsFile = inputs.self + "/secrets/dafpi/litellm.yaml";
            })
          // {
            # Hashed by dafoltop's Authelia (authelia-peers), so readable by both.
            "litellm/authelia/client-secret".sopsFile = inputs.self + "/secrets/dafoltop/litellm.yaml";
          };

        nps.stacks.litellm = {
          enable = true;
          dbPasswordFile = secret "db-password";
          masterKeyFile = secret "master-key";
          # A new SSO user is an admin: the Authelia group is the gate and
          # the free tier caps SSO at 5 users. Applies at first login only.
          settings = lib.recursiveUpdate (import ./_settings.nix) {
            litellm_settings.default_internal_user_params.user_role = "proxy_admin";
          };

          containers = {
            litellm = {
              traefik.subDomain = cfg.subDomain;
              wants = secretsDep;
            };
            litellm-db.wants = secretsDep;
          };
        };

        # The client is served by dafoltop's Authelia (authelia-peers), which
        # hashes the secret there; nothing in the store.
        nps.stacks.authelia = {
          oidc.clients.litellm = {
            client_name = "LiteLLM";
            client_secret.toHash = oidcSecret;
            public = false;
            authorization_policy = "litellm";
            claims_policy = "litellm";
            require_pkce = false;
            pkce_challenge_method = "";
            pre_configured_consent_duration = config.nps.stacks.authelia.oidc.defaultConsentDuration;
            redirect_uris = [ "${serviceUrl}/sso/callback" ];
          };

          settings.identity_providers.oidc = {
            claims_policies.litellm.id_token = [
              "email"
              "email_verified"
              "alt_emails"
              "preferred_username"
              "name"
            ];
            authorization_policies.litellm = {
              default_policy = "deny";
              rules = [
                {
                  policy = config.nps.stacks.authelia.defaultAllowPolicy;
                  subject = "group:${userGroup}";
                }
              ];
            };
          };
        };

        nps.stacks.lldap.bootstrap.groups.${userGroup} = { };

        # Generic SSO: the user id defaults to preferred_username (the lldap
        # login), the scope to "openid email profile". The UI has no static
        # login (disable_env_credential_login); the master key is API-only.
        services.podman.containers.litellm.extraEnv = {
          PROXY_BASE_URL = serviceUrl;
          GENERIC_CLIENT_ID = "litellm";
          GENERIC_CLIENT_SECRET.fromFile = oidcSecret;
          GENERIC_AUTHORIZATION_ENDPOINT = "${autheliaUrl}/api/oidc/authorization";
          GENERIC_TOKEN_ENDPOINT = "${autheliaUrl}/api/oidc/token";
          GENERIC_USERINFO_ENDPOINT = "${autheliaUrl}/api/oidc/userinfo";
        };
      };
    };
}
