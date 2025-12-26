{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:

let
  inherit (lib.${namespace}) mkBoolOpt;
  inherit (pkgs.dafos) wallpapers;
in
{
  options.${namespace}.desktop.addons.wallpapers = {
    enable = mkBoolOpt false "Whether or not to add wallpapers to ~/Pictures/Wallpapers.";
  };

  config = {
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

    services.swww.enable = true;

    xdg.dataFile."change_wallpaper.sh" = {
      enable = true;
      text = ''
        set -e
        while true; do
          BG=`find ${config.home.homeDirectory}/Pictures/Wallpapers -name "*.jpg" -o -name "*.png" | shuf -n1`
          if pgrep swww-daemon >/dev/null; then
            swww img "$BG" \
              --transition-fps 60 \
              --transition-duration 2 \
              --transition-type random \
              --transition-pos top-right \
              --transition-bezier .3,0,0,.99 \
              --transition-angle 135 || true
          else
            (swww-daemon 1>/dev/null 2>/dev/null &) || true
          fi
          sleep 18
        done
      '';
    };
  };
}
