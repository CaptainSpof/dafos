{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.services.papra;
in
  {

    options.${namespace}.services.papra = {
      enable = mkEnableOption "Whether or not to configure papra.";
      base-url = mkOpt types.str "papra.daftdaf.dev" "The base url";
    };

    config = mkIf cfg.enable {
      sops.secrets = {
        "cloudflare-api-token" = {
          sopsFile = lib.snowfall.fs.get-file "secrets/daf/cloudflare.yaml";
        };
        "papra/auth-secret" = {
          sopsFile = lib.snowfall.fs.get-file "secrets/daf/papra.yaml";
        };
        "papra/authelia/client-secret" = {
          sopsFile = lib.snowfall.fs.get-file "secrets/daf/papra.yaml";
        };
      };

      nps.stacks = {
        papra = {
          enable = true;

          authSecretFile = config.sops.secrets."papra/auth-secret".path;

          oidc = {
            enable = true;
            clientSecretFile = config.sops.secrets."papra/authelia/client-secret".path;
          };

          containers.papra = {
            expose = true;
          };
        };
      };
    };
  }
