# Bar Assistant (local nps stack, modules/home/stacks/bar-assistant): cocktail
# recipes and bar inventory, OIDC through Authelia, public. Runs on dafpi:
# its OIDC client and lldap group are served by dafoltop's Authelia/lldap
# through authelia-peers, and the public routes go through dafoltop's Traefik
# (traefik peers). A pure dendritic host also imports `bar-assistant-stack`
# (./local-stacks.nix).
{ inputs, ... }:
{
  flake.modules.homeManager.bar-assistant =
    { config, lib, ... }:
    let
      inherit (lib)
        mkEnableOption
        mkIf
        mkOption
        types
        ;
      opt =
        type: default: description:
        mkOption { inherit type default description; };

      cfg = config.dafos.services.bar-assistant;
    in
    {
      options.dafos.services.bar-assistant = {
        enable = mkEnableOption "Whether or not to configure bar-assistant.";
        subDomain = opt types.str "bar" "The subdomain the Salt Rim web client is served on";
        apiSubDomain = opt types.str "bar-api" "The subdomain the API server is served on";
        searchSubDomain = opt types.str "bar-search" "The subdomain Meilisearch is served on";
      };

      config = mkIf cfg.enable {
        sops.secrets = {
          "bar-assistant/meili-master-key".sopsFile = inputs.self + "/secrets/dafoltop/bar-assistant.yaml";
          "bar-assistant/authelia/client-secret".sopsFile =
            inputs.self + "/secrets/dafoltop/bar-assistant.yaml";
        };

        nps.stacks.bar-assistant = {
          enable = true;

          meiliMasterKeyFile = config.sops.secrets."bar-assistant/meili-master-key".path;
          defaultLocale = "fr-FR";

          oidc = {
            enable = true;
            clientSecretFile = config.sops.secrets."bar-assistant/authelia/client-secret".path;
            # Authelia is a peer's where this host runs none.
            issuerUrl = mkIf (
              !config.nps.stacks.authelia.enable
            ) "https://auth.${config.nps.stacks.traefik.domain}";
          };
          # Upstream's SSO login creates accounts through the same registration
          # service, so a first-time Authelia user is refused too: flip this back
          # temporarily to onboard someone.
          allowRegistration = false;

          # Salt Rim runs in the browser and calls the API and Meilisearch
          # directly, so all three have to be reachable from wherever the client is.
          containers = {
            bar-assistant-salt-rim = {
              expose = true;
              traefik.subDomain = cfg.subDomain;
            };
            bar-assistant = {
              expose = true;
              traefik.subDomain = cfg.apiSubDomain;
            };
            bar-assistant-meilisearch = {
              expose = true;
              traefik.subDomain = cfg.searchSubDomain;

              # Meilisearch owns the search index on disk, so keep it off the
              # unattended Sunday registry pull (see the grimmory module for the
              # full reasoning) even though its tag is pinned.
              autoUpdate = "local";
            };

            # `redis:8` is a moving tag; same reasoning.
            bar-assistant-redis.autoUpdate = "local";
          };
        };
      };
    };
}
