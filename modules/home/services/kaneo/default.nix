{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) mkOpt mkBoolOpt;

  cfg = config.${namespace}.services.kaneo;
in
{

  options.${namespace}.services.kaneo = {
    enable = mkEnableOption "Whether or not to configure kaneo.";
    subDomain = mkOpt types.str "kaneo" "The subdomain of the web frontend.";
    apiSubDomain = mkOpt types.str "kaneo-api" "The subdomain of the backend API.";
    expose = mkBoolOpt false "Whether to reach the instance from outside the LAN/tailnet.";
  };

  config = mkIf cfg.enable {
    sops.secrets = {
      "kaneo/auth-secret" = {
        sopsFile = lib.snowfall.fs.get-file "secrets/daf/kaneo.yaml";
      };
      "kaneo/db-password" = {
        sopsFile = lib.snowfall.fs.get-file "secrets/daf/kaneo.yaml";
      };
      "kaneo/authelia/client-secret" = {
        sopsFile = lib.snowfall.fs.get-file "secrets/daf/kaneo.yaml";
      };
    };

    nps.stacks = {
      kaneo = {
        enable = true;

        authSecretFile = config.sops.secrets."kaneo/auth-secret".path;
        db.passwordFile = config.sops.secrets."kaneo/db-password".path;

        oidc = {
          enable = true;
          clientSecretFile = config.sops.secrets."kaneo/authelia/client-secret".path;
        };

        containers = {
          kaneo-web = {
            inherit (cfg) expose;
            traefik.subDomain = cfg.subDomain;
          };

          kaneo-api = {
            inherit (cfg) expose;
            port = 1337;
            traefik.subDomain = cfg.apiSubDomain;
          };
        };
      };
    };
  };
}
