{
  config,
  lib,
  namespace,
  pkgs,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.system.xdg;

  browser = [
    "firefox-beta.desktop"
    "firefox.desktop"
  ];
  editor = [ "emacs.desktop" ];
  excel = [ "libreoffice-calc.desktop" ];
  fileManager = [ "org.kde.dolphin.desktop" ];
  archive = [ "org.kde.ark.desktop" ];
  image = [ "org.kde.gwenview.desktop" ];
  mail = [ "emacs.desktop" ];
  powerpoint = [ "libreoffice-impress.desktop" ];
  terminal = [
    "org.wezfurlong.wezterm.desktop"
    "kitty.desktop"
  ];
  video = [ "vlc.desktop" ];
  word = [ "libreoffice-writer.desktop" ];

  # XDG MIME types
  associations = {
    "application/json" = editor;
    "application/pdf" = [ "okular.desktop" ];
    "application/rss+xml" = editor;
    "application/vnd.ms-excel" = excel;
    "application/vnd.ms-powerpoint" = powerpoint;
    "application/vnd.ms-word" = word;
    "application/vnd.oasis.opendocument.database" = [ "libreoffice-base.desktop" ];
    "application/vnd.oasis.opendocument.formula" = [ "libreoffice-math.desktop" ];
    "application/vnd.oasis.opendocument.graphics" = [ "libreoffice-draw.desktop" ];
    "application/vnd.oasis.opendocument.graphics-template" = [ "libreoffice-draw.desktop" ];
    "application/vnd.oasis.opendocument.presentation" = powerpoint;
    "application/vnd.oasis.opendocument.presentation-template" = powerpoint;
    "application/vnd.oasis.opendocument.spreadsheet" = excel;
    "application/vnd.oasis.opendocument.spreadsheet-template" = excel;
    "application/vnd.oasis.opendocument.text" = word;
    "application/vnd.oasis.opendocument.text-master" = word;
    "application/vnd.oasis.opendocument.text-template" = word;
    "application/vnd.oasis.opendocument.text-web" = word;
    "application/vnd.openxmlformats-officedocument.presentationml.presentation" = powerpoint;
    "application/vnd.openxmlformats-officedocument.presentationml.template" = powerpoint;
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = excel;
    "application/vnd.openxmlformats-officedocument.spreadsheetml.template" = excel;
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = word;
    "application/vnd.openxmlformats-officedocument.wordprocessingml.template" = word;
    "application/vnd.stardivision.calc" = excel;
    "application/vnd.stardivision.draw" = [ "libreoffice-draw.desktop" ];
    "application/vnd.stardivision.impress" = powerpoint;
    "application/vnd.stardivision.math" = [ "libreoffice-math.desktop" ];
    "application/vnd.stardivision.writer" = word;
    "application/vnd.sun.xml.base" = [ "libreoffice-base.desktop" ];
    "application/vnd.sun.xml.calc" = excel;
    "application/vnd.sun.xml.calc.template" = excel;
    "application/vnd.sun.xml.draw" = [ "libreoffice-draw.desktop" ];
    "application/vnd.sun.xml.draw.template" = [ "libreoffice-draw.desktop" ];
    "application/vnd.sun.xml.impress" = powerpoint;
    "application/vnd.sun.xml.impress.template" = powerpoint;
    "application/vnd.sun.xml.math" = [ "libreoffice-math.desktop" ];
    "application/vnd.sun.xml.writer" = word;
    "application/vnd.sun.xml.writer.global" = word;
    "application/vnd.sun.xml.writer.template" = word;
    "application/vnd.wordperfect" = word;
    "application/x-arj" = archive;
    "application/x-bittorrent" = [ "org.qbittorrent.qBittorrent.desktop" ];
    "application/x-bzip" = archive;
    "application/x-bzip-compressed-tar" = archive;
    "application/x-compress" = archive;
    "application/x-compressed-tar" = archive;
    "application/x-extension-htm" = browser;
    "application/x-extension-html" = browser;
    "application/x-extension-ics" = mail;
    "application/x-extension-m4a" = video;
    "application/x-extension-mp4" = video;
    "application/x-extension-shtml" = browser;
    "application/x-extension-xht" = browser;
    "application/x-extension-xhtml" = browser;
    "application/x-flac" = video;
    "application/x-gzip" = archive;
    "application/x-lha" = archive;
    "application/x-lhz" = archive;
    "application/x-lzop" = archive;
    "application/x-matroska" = video;
    "application/x-netshow-channel" = video;
    "application/x-quicktime-media-link" = video;
    "application/x-quicktimeplayer" = video;
    "application/x-rar" = archive;
    "application/x-shellscript" = editor;
    "application/x-smil" = video;
    "application/x-tar" = archive;
    "application/x-tarz" = archive;
    "application/x-wine-extension-ini" = [ "org.kde.kate.desktop" ];
    "application/x-zoo" = archive;
    "application/xhtml+xml" = browser;
    "application/xml" = editor;
    "application/zip" = archive;
    "audio/*" = video;
    "image/*" = image;
    "image/bmp" = image;
    "image/gif" = image;
    "image/jpeg" = image;
    "image/jpg" = image;
    "image/pjpeg" = image;
    "image/png" = image;
    "image/svg+xml" = [ "org.inkscape.Inkscape.desktop" ];
    "image/tiff" = image;
    "image/x-compressed-xcf" = [ "gimp.desktop" ];
    "image/x-fits" = [ "gimp.desktop" ];
    "image/x-icb" = image;
    "image/x-ico" = image;
    "image/x-pcx" = image;
    "image/x-portable-anymap" = image;
    "image/x-portable-bitmap" = image;
    "image/x-portable-graymap" = image;
    "image/x-portable-pixmap" = image;
    "image/x-psd" = [ "gimp.desktop" ];
    "image/x-xbitmap" = image;
    "image/x-xcf" = [ "gimp.desktop" ];
    "image/x-xpixmap" = image;
    "image/x-xwindowdump" = image;
    "inode/directory" = fileManager;
    "message/rfc822" = mail;
    "text/*" = editor;
    "text/calendar" = mail;
    "text/html" = browser;
    "text/plain" = editor;
    "video/*" = video;
    "x-scheme-handler/about" = browser;
    "x-scheme-handler/chrome" = browser;
    "x-scheme-handler/discord" = [ "discord.desktop" ]; # TODO: vesktop?
    "x-scheme-handler/ftp" = browser;
    "x-scheme-handler/http" = browser;
    "x-scheme-handler/https" = browser;
    "x-scheme-handler/mailto" = mail;
    "x-scheme-handler/mid" = mail;
    "x-scheme-handler/spotify" = [ "spotify.desktop" ];
    "x-scheme-handler/terminal" = terminal;
    "x-scheme-handler/tg" = [ "org.telegram.desktop" ];
    "x-scheme-handler/unknown" = browser;
    "x-scheme-handler/webcal" = mail;
    "x-scheme-handler/webcals" = mail;
    "x-www-browser" = browser;
  };
in
{
  options.${namespace}.system.xdg = {
    enable = mkEnableOption "Whether to configure xdg.";

    terminal = mkOpt types.str "wezterm" "The default terminal.";
    editor = mkOpt types.str "emacs" "The default editor.";
  };

  config = mkIf cfg.enable {

    home = {
      sessionVariables = {
        TERMINAL = cfg.terminal;
        EDITOR = cfg.editor;
        XDG_MENU_PREFIX = "plasma-";
      };
    };


    xdg = {
      enable = true;
      cacheHome = config.home.homeDirectory + "/.local/cache";

      mimeApps = {
        enable = true;
        defaultApplications = associations;
        associations.added = associations;
      };
    };
  };
}
