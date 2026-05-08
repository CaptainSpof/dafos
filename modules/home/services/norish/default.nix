{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.services.norish;
in
  {

    options.${namespace}.services.norish = {
      enable = mkEnableOption "Whether or not to configure norish.";
      subDomain = mkOpt types.str "norish" "The base url";
    };

    config = mkIf cfg.enable {
      sops.secrets = {
        "norish/master-key" = {
          sopsFile = lib.snowfall.fs.get-file "secrets/daf/norish.yaml";
        };
        "norish/db-password" = {
          sopsFile = lib.snowfall.fs.get-file "secrets/daf/norish.yaml";
        };
        "norish/authelia/client-secret" = {
          sopsFile = lib.snowfall.fs.get-file "secrets/daf/norish.yaml";
        };
      };

      nps.stacks = {
        norish = {
          enable = true;

          masterKeyFile = config.sops.secrets."norish/master-key".path;
          db.passwordFile = config.sops.secrets."norish/db-password".path;

          oidc = {
            enable = true;
            clientSecretFile = config.sops.secrets."norish/authelia/client-secret".path;
          };

          containers.norish = {
            expose = true;
            traefik.subDomain = cfg.subDomain;
          };
        };
      };

    };
  }
