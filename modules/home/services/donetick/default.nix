{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.services.donetick;
in
  {

    options.${namespace}.services.donetick = {
      enable = mkEnableOption "Whether or not to configure donetick.";
      base-url = mkOpt types.str "donetick.daftdaf.dev" "The base url";
      port = mkOpt types.int 8086 "The port";
    };

    config = mkIf cfg.enable {
      sops = {
        secrets = {
          "cloudflare-api-token" = {
            sopsFile = lib.snowfall.fs.get-file "secrets/daf/cloudflare.yaml";
          };
          "donetick/jwt-secret" = {
            sopsFile = lib.snowfall.fs.get-file "secrets/daf/donetick.yaml";
          };
          "donetick/authelia/client-secret" = {
            sopsFile = lib.snowfall.fs.get-file "secrets/daf/donetick.yaml";
          };
        };
      };

      nps.stacks = {
        donetick = {
          enable = true;

          settings.is_user_creation_disabled = true;
          jwtSecretFile = config.sops.secrets."donetick/jwt-secret".path;

          oidc = {
            enable = true;
            clientSecretFile = config.sops.secrets."donetick/authelia/client-secret".path;
          };
        };
      };

    };
  }
