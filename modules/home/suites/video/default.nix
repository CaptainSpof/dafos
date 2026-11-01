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

  # The streaming server only probes FHS paths for ffmpeg; without it casting
  # (which transcodes) spawns `null` and fails.
  stremioWithFfmpeg = pkgs.symlinkJoin {
    name = "stremio-linux-shell-with-ffmpeg";
    paths = [ pkgs.stremio-linux-shell ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/stremio \
        --set FFMPEG_BIN ${lib.getExe' pkgs.ffmpeg "ffmpeg"} \
        --set FFPROBE_BIN ${lib.getExe' pkgs.ffmpeg "ffprobe"}
    '';
  };
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
        freetube
        stremioWithFfmpeg
      ]
      ++ lib.optionals cfg.jellyfin.enable [ jellyfin-media-player ]
      ++ lib.optionals cfg.mpv.enable [
        mpv
        haruna
      ]
      ++ lib.optionals cfg.editing.enable [ kdenlive ];

    dafos = {
      programs.graphical.apps = {
        obs.enable = cfg.recording.enable;
      };
    };
  };
}
