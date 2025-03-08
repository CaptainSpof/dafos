{
  lib,
  config,
  namespace,
  ...
}:

let
  cfg = config.${namespace}.services.audiobookshelf;

  inherit (lib) mkEnableOption mkIf;
in
{
  options.${namespace}.services.audiobookshelf = {
    enable = mkEnableOption "Whether or not to configure audiobookshelf.";
  };

  config = mkIf cfg.enable {
    users.groups.yahrr.members = [ "audiobookshelf" ];
    services.audiobookshelf = {
      enable = true;
      openFirewall = true;
      port = 8002;
      host = "0.0.0.0";
    };
  };
}
