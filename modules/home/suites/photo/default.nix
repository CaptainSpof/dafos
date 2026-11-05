{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.suites.photo;
in
{
  options.${namespace}.suites.photo = {
    enable = mkBoolOpt false "Whether or not to enable photo configuration.";
    digikam.enable = mkBoolOpt false "Whether or not to enable digiKam.";
  };

  config = mkIf cfg.enable {
    home.packages =
      with pkgs;
      # Bulk uploads to Immich (immich.daftdaf.dev on dafoltop).
      [ immich-go ] ++ lib.optionals (cfg.digikam.enable && stdenv.isLinux) [ digikam ];
  };
}
