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

  cfg = config.${namespace}.suites.video;
in
{
  options.${namespace}.suites.video = {
    enable = mkBoolOpt false "Whether or not to enable video configuration.";
    editing.enable = mkBoolOpt false "Whether or not to enable video editing configuration.";
    jellyfin.enable = mkBoolOpt true "Whether or not to enable jellyfin configuration.";
    mpv.enable = mkBoolOpt true "Whether or not to enable mpv configuration.";
    recording.enable = mkBoolOpt false "Whether or not to enable video recording configuration.";
  };

  config = mkIf cfg.enable {

    home.packages =
      with pkgs;
      [
        vlc
        yt-dlp
        # stremio
        freetube
      ]
      ++ lib.optionals cfg.jellyfin.enable [ jellyfin-media-player ]
      ++ lib.optionals cfg.mpv.enable [ mpv haruna ]
      ++ lib.optionals cfg.editing.enable [ kdenlive ];

    dafos = {
      programs.graphical.apps = {
        obs.enable = cfg.recording.enable;
      };
    };
  };
}
