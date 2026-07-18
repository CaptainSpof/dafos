{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.services.sparky-fitness;
in
{

  options.${namespace}.services.sparky-fitness = {
    enable = mkEnableOption "Whether or not to configure sparky-fitness.";
    subDomain = mkOpt types.str "sparky-fitness" "The base url";
  };

  config = mkIf cfg.enable {
    sops.secrets = {
      "sparky-fitness/better-auth-secret" = {
        sopsFile = lib.snowfall.fs.get-file "secrets/daf/sparkyfitness.yaml";
      };
      "sparky-fitness/api-encryption-key" = {
        sopsFile = lib.snowfall.fs.get-file "secrets/daf/sparkyfitness.yaml";
      };
      "sparky-fitness/db-password" = {
        sopsFile = lib.snowfall.fs.get-file "secrets/daf/sparkyfitness.yaml";
      };
      "sparky-fitness/authelia/client-secret" = {
        sopsFile = lib.snowfall.fs.get-file "secrets/daf/sparkyfitness.yaml";
      };
    };

    nps.stacks = {
      sparky-fitness = {
        enable = true;

        betterAuthSecretFile = config.sops.secrets."sparky-fitness/better-auth-secret".path;
        apiEncryptionKeyFile = config.sops.secrets."sparky-fitness/api-encryption-key".path;
        db.passwordFile = config.sops.secrets."sparky-fitness/db-password".path;

        oidc = {
          enable = true;
          clientSecretFile = config.sops.secrets."sparky-fitness/authelia/client-secret".path;
        };

        containers.sparky-fitness-frontend = {
          traefik.subDomain = cfg.subDomain;
        };
      };
    };

  };
}
