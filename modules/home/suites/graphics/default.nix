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

  cfg = config.${namespace}.suites.graphics;
in
{
  options.${namespace}.suites.graphics = {
    enable = mkBoolOpt false "Whether or not to enable art configuration.";
    drawing.enable = mkBoolOpt false "Whether or not to enable art drawing configuration.";
    graphics3d.enable = mkBoolOpt false "Whether or not to enable art graphics 3D configuration.";
    raster.enable = mkBoolOpt false "Whether or not to enable art raster configuration.";
    upscaling.enable = mkBoolOpt false "Whether or not to enable art upscaling configuration.";
    vector.enable = mkBoolOpt false "Whether or not to enable art vector configuration.";
    whiteboard.enable = mkBoolOpt false "Whether or not to enable art whiteboard configuration.";
  };

  config = mkIf cfg.enable {
    home.packages =
      with pkgs;
      lib.optionals cfg.drawing.enable [ krita ]
      ++ lib.optionals cfg.vector.enable [
        (inkscape-with-extensions.override { inkscapeExtensions = [ inkscape-extensions.silhouette ]; })
      ]
      ++ lib.optionals cfg.graphics3d.enable [ blender ]
      ++ lib.optionals cfg.raster.enable [ gimp ]
      ++ lib.optionals cfg.upscaling.enable [ upscayl ]
      ++ lib.optionals cfg.whiteboard.enable [ drawy ]
      ++ [ libwebp ];
  };
}
