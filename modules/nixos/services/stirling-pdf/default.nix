{
  config,
  lib,
  namespace,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.services.stirling-pdf;
in
{
  options.${namespace}.services.stirling-pdf = {
    enable = mkBoolOpt false "Whether or not to enable stirling-pdf";
  };

  config = mkIf cfg.enable {
    services.stirling-pdf = {
      enable = true;
      environment = {
        SERVER_PORT = 8001;
      };
    };
  };
}
