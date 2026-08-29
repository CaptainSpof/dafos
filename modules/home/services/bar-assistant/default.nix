{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.services.bar-assistant;
in
{

  options.${namespace}.services.bar-assistant = {
    enable = mkEnableOption "Whether or not to configure bar-assistant.";
    subDomain = mkOpt types.str "bar" "The subdomain the Salt Rim web client is served on";
    apiSubDomain = mkOpt types.str "bar-api" "The subdomain the API server is served on";
    searchSubDomain = mkOpt types.str "bar-search" "The subdomain Meilisearch is served on";
  };

  config = mkIf cfg.enable {
    sops.secrets."bar-assistant/meili-master-key" = {
      sopsFile = lib.snowfall.fs.get-file "secrets/daf/bar-assistant.yaml";
    };

    nps.stacks.bar-assistant = {
      enable = true;

      meiliMasterKeyFile = config.sops.secrets."bar-assistant/meili-master-key".path;
      defaultLocale = "fr-FR";
      # Kept open to match the pre-migration deployment; flip to false once
      # every account that needs one exists.
      allowRegistration = true;

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
        };
      };
    };
  };
}
