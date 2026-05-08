{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.services.karakeep;
in
  {

    options.${namespace}.services.karakeep = {
      enable = mkEnableOption "Whether or not to configure karakeep.";
      base-url = mkOpt types.str "karakeep.daftdaf.dev" "The base url";
    };

    config = mkIf cfg.enable {
      sops.secrets = {
        "karakeep/nextauth-secret".sopsFile = lib.snowfall.fs.get-file "secrets/daf/karakeep.yaml";
        "karakeep/meili-master-key".sopsFile = lib.snowfall.fs.get-file "secrets/daf/karakeep.yaml";
        "karakeep/authelia/client-secret".sopsFile = lib.snowfall.fs.get-file "secrets/daf/karakeep.yaml";
      };

      nps.stacks = {
        karakeep = {
          enable = true;

          oidc = {
            enable = true;
            clientSecretFile = config.sops.secrets."karakeep/authelia/client-secret".path;
          };
          nextauthSecretFile = config.sops.secrets."karakeep/nextauth-secret".path;
          meiliMasterKeyFile = config.sops.secrets."karakeep/meili-master-key".path;

          containers.karakeep.extraEnv = {
            DISABLE_SIGNUPS = true;
            DISABLE_PASSWORD_AUTH = true;
          };
        };
      };

    };
  }
