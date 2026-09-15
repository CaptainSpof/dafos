{
  config,
  lib,
  namespace,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.suites.yahrr;
in
{
  options.${namespace}.suites.yahrr = {
    enable = mkBoolOpt false "Whether or not to enable yahrr configuration.";
  };

  config = mkIf cfg.enable {
    dafos = {
      user.extraGroups = [ "yahrr" ];
      apps = {
        qbittorrent = {
          enable = false;
          nox.enable = false;
        };
      };
    };
  };
}
