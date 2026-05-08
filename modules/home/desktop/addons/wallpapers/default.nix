{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;
  inherit (pkgs.dafos) wallpapers;

  cfg = config.${namespace}.desktop.addons.wallpapers;
in
{
  options.${namespace}.desktop.addons.wallpapers = {
    enable = mkBoolOpt false "Whether or not to add wallpapers to ~/Pictures/Wallpapers.";
  };

  config = mkIf cfg.enable {
    home.file =
      (lib.foldl (
        acc: name:
        let
          wallpaper = wallpapers.${name};
        in
        acc
        // {
          # The loop builds the hierarchical paths
          "Pictures/Wallpapers/${wallpaper.fileName}".source = wallpaper;
        }
      ) { } wallpapers.names)
      # Merge the single flattened entry AFTER the loop finishes
      // {
        "Pictures/Wallpapers/Flatten".source = wallpapers.flattened;
      };
  };
}
