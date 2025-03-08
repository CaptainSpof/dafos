{
  lib,
  config,
  namespace,
  ...
}:

let
  cfg = config.${namespace}.services.readarr;

  inherit (lib.${namespace}) mkOpt;
  inherit (lib) types mkEnableOption mkIf;
in
{
  options.${namespace}.services.readarr = {
    enable = mkEnableOption "Whether or not to configure readarr.";
    dataDir = mkOpt types.str "/var/lib/readarr" "The directory where Readarr stores its data files.";
  };

  config = mkIf cfg.enable {
    dafos.user.extraGroups = [ "readarr" ];
    users.groups.yahrr.members = [ "readarr" ];
    services.readarr = {
      enable = true;
      # port = 8787; # For reference
      openFirewall = true;
    };
    systemd.tmpfiles.settings."10-readarr".${cfg.dataDir}.d = {
      mode = "0755";
    };
  };
}
