{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.services.it-tools;
in
  {

    options.${namespace}.services.it-tools = {
      enable = mkEnableOption "Whether or not to configure it-tools.";
      base-url = mkOpt types.str "it-tools.daftdaf.dev" "The base url";
      port = mkOpt types.int 8086 "The port";
    };

    config = mkIf cfg.enable {
      sops.secrets."cloudflare-api-token" = {
        sopsFile = lib.snowfall.fs.get-file "secrets/daf/cloudflare.yaml";
      };

      nps.stacks = {
        it-tools = {
          enable = true;
        };
      };

    };
  }
