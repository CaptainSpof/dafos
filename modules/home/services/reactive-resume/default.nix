{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.services.reactive-resume;
in
  {

    options.${namespace}.services.reactive-resume = {
      enable = mkEnableOption "Whether or not to configure reactive-resume.";
      base-url = mkOpt types.str "cv.daftdaf.dev" "The base url";
    };

    config = mkIf cfg.enable {
      sops.secrets = {
        "cloudflare-api-token" = {
          sopsFile = lib.snowfall.fs.get-file "secrets/daf/cloudflare.yaml";
        };
        "reactive-resume/auth-secret" = {
          sopsFile = lib.snowfall.fs.get-file "secrets/daf/reactive-resume.yaml";
        };
        "reactive-resume/db-password" = {
          sopsFile = lib.snowfall.fs.get-file "secrets/daf/reactive-resume.yaml";
        };
        "reactive-resume/authelia/client-secret" = {
          sopsFile = lib.snowfall.fs.get-file "secrets/daf/reactive-resume.yaml";
        };
      };

      nps.stacks = {
        reactive-resume = {
          enable = true;

          authSecretFile = config.sops.secrets."reactive-resume/auth-secret".path;
          db.passwordFile = config.sops.secrets."reactive-resume/db-password".path;

          oidc = {
            enable = true;
            clientSecretFile = config.sops.secrets."reactive-resume/authelia/client-secret".path;
          };

          containers.reactive-resume = {
            traefik.subDomain = "cv";
            expose = true;
          };
        };
      };
    };
  }
