# Papra (nps stack): document archive, OIDC through Authelia, public.
# Runs on dafpi: its OIDC client and lldap group are served by dafoltop's
# Authelia/lldap through authelia-peers, and the public route goes through
# dafoltop's Traefik (traefik peers), which the Freebox forwards :443 to.
{ inputs, ... }:
{
  flake.modules.homeManager.papra =
    { config, lib, ... }:
    {
      options.dafos.services.papra.enable = lib.mkEnableOption "Papra";

      config = lib.mkIf config.dafos.services.papra.enable {
        # The same secrets (same names, so same paths) are what dafoltop's
        # Authelia hashes the client secret from.
        sops.secrets = {
          "papra/auth-secret".sopsFile = inputs.self + "/secrets/dafoltop/papra.yaml";
          "papra/authelia/client-secret".sopsFile = inputs.self + "/secrets/dafoltop/papra.yaml";
        };

        nps.stacks.papra = {
          enable = true;

          authSecretFile = config.sops.secrets."papra/auth-secret".path;

          oidc = {
            enable = true;
            clientSecretFile = config.sops.secrets."papra/authelia/client-secret".path;
          };

          containers.papra.expose = true;
        };

        # nps builds the provider from the *local* authelia container's URL,
        # which does not exist where Authelia is a peer's: same JSON, fixed
        # URL. The overridden definition is never evaluated.
        services.podman.containers.papra.extraEnv.AUTH_PROVIDERS_CUSTOMS =
          lib.mkIf (!config.nps.stacks.authelia.enable)
            (
              lib.mkForce {
                fromTemplate = builtins.toJSON [
                  {
                    providerId = "authelia";
                    providerName = "Authelia";
                    providerIconUrl = "https://www.authelia.com/images/branding/logo-cropped.png";
                    clientId = "papra";
                    clientSecret = "{{ file.Read `${config.sops.secrets."papra/authelia/client-secret".path}`}}";
                    type = "oidc";
                    pkce = true;
                    discoveryUrl = "https://auth.${config.nps.stacks.traefik.domain}/.well-known/openid-configuration";
                    scopes = [
                      "openid"
                      "profile"
                      "email"
                    ];
                  }
                ];
              }
            );
      };
    };
}
