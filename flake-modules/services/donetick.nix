# Donetick (nps stack): chores, OIDC through Authelia, private. Home
# Assistant's donetick integration (dafoltop) reaches it by its hostname.
# Runs on dafpi: its OIDC client and lldap group are served by dafoltop's
# Authelia/lldap through authelia-peers.
{ inputs, ... }:
{
  flake.modules.homeManager.donetick =
    { config, lib, ... }:
    let
      autheliaUrl = "https://auth.${config.nps.stacks.traefik.domain}";
      serviceUrl = config.services.podman.containers.donetick.traefik.serviceUrl;
    in
    {
      options.dafos.services.donetick.enable = lib.mkEnableOption "Donetick";

      config = lib.mkIf config.dafos.services.donetick.enable (
        lib.mkMerge [
          {
            sops.secrets = {
              "donetick/jwt-secret".sopsFile = inputs.self + "/secrets/dafoltop/donetick.yaml";
              "donetick/authelia/client-secret".sopsFile = inputs.self + "/secrets/dafoltop/donetick.yaml";
            };

            nps.stacks.donetick = {
              enable = true;

              settings.is_user_creation_disabled = true;
              jwtSecretFile = config.sops.secrets."donetick/jwt-secret".path;

              oidc = {
                enable = true;
                clientSecretFile = config.sops.secrets."donetick/authelia/client-secret".path;
              };
            };

            # nix-podman-stacks only registers the web callback. The Android app is a
            # Capacitor build: it opens the system browser and expects the code back on
            # its own deep link, so that URI has to be pre-registered too, otherwise
            # Authelia rejects the authorize request with `invalid_request`.
            nps.stacks.authelia.oidc.clients.donetick.redirect_uris = lib.mkForce [
              "${serviceUrl}/auth/oauth2"
              "donetick://auth/oauth2"
            ];
          }

          # nps builds the endpoints from the *local* authelia container's URL,
          # which does not exist where Authelia is a peer's (see ./papra.nix).
          (lib.mkIf (!config.nps.stacks.authelia.enable) {
            services.podman.containers.donetick.wantsContainer = lib.mkForce [ ];
            nps.stacks.donetick.settings.oauth2 = lib.mkForce {
              name = "Authelia";
              client_id = "donetick";
              client_secret = "";
              auth_url = "${autheliaUrl}/api/oidc/authorization";
              token_url = "${autheliaUrl}/api/oidc/token";
              user_info_url = "${autheliaUrl}/api/oidc/userinfo";
              redirect_url = "${serviceUrl}/auth/oauth2";
              scopes = [
                "openid"
                "profile"
                "email"
              ];
            };
          })
        ]
      );
    };
}
