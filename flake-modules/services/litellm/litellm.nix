# LiteLLM (local nps stack, modules/home/stacks/litellm) on dafpi: the
# llm.daftdaf.dev OpenAI-compatible endpoint the Kobo's X-Ray plugin calls,
# relaying to dafbox's Ollama and logging every request (UI: /ui). Private
# gate (LAN/tailnet); the API needs a LiteLLM key, the UI its admin password.
# A pure dendritic host also imports `litellm-stack` (../local-stacks.nix).
{ inputs, ... }:
{
  flake.modules.homeManager.litellm =
    { config, lib, ... }:
    let
      cfg = config.dafos.services.litellm;
      secret = key: config.sops.secrets."litellm/${key}".path;
      secretsDep = [ "sops-nix.service" ];
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
              "litellm/ui-password"
            ]
            (_: {
              sopsFile = inputs.self + "/secrets/dafpi/litellm.yaml";
            });

        nps.stacks.litellm = {
          enable = true;
          dbPasswordFile = secret "db-password";
          masterKeyFile = secret "master-key";
          uiPasswordFile = secret "ui-password";
          settings = import ./_settings.nix;

          containers = {
            litellm = {
              traefik.subDomain = cfg.subDomain;
              wants = secretsDep;
            };
            litellm-db.wants = secretsDep;
          };
        };
      };
    };
}
