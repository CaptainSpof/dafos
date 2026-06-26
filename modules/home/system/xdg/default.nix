{
  config,
  lib,
  namespace,
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
  mail = [ "emacs.desktop" ];
  terminal = [
    "org.wezfurlong.wezterm.desktop"
    "kitty.desktop"
  ];

  # KDE applications
  archive = [ "org.kde.ark.desktop" ];
  fileManager = [ "org.kde.dolphin.desktop" ];
  image = [ "org.kde.gwenview.desktop" ];
  pdf = [ "org.kde.okular.desktop" ];

  # LibreOffice
  base = [ "libreoffice-base.desktop" ];
  draw = [ "libreoffice-draw.desktop" ];
  excel = [ "libreoffice-calc.desktop" ];
  math = [ "libreoffice-math.desktop" ];
  powerpoint = [ "libreoffice-impress.desktop" ];
  word = [ "libreoffice-writer.desktop" ];

  # Other graphical apps
  gimp = [ "gimp.desktop" ];
  svg = [ "org.inkscape.Inkscape.desktop" ];
  torrent = [ "org.qbittorrent.qBittorrent.desktop" ];
  video = [ "vlc.desktop" ];

  # XDG MIME types
  associations = {
    "application/epub+zip" = pdf;
    "application/json" = editor;
    "application/pdf" = pdf;
    "application/rss+xml" = editor;
    "application/vnd.ms-excel" = excel;
    "application/vnd.ms-powerpoint" = powerpoint;
    "application/vnd.ms-word" = word;
    "application/vnd.oasis.opendocument.database" = base;
    "application/vnd.oasis.opendocument.formula" = math;
    "application/vnd.oasis.opendocument.graphics" = draw;
    "application/vnd.oasis.opendocument.graphics-template" = draw;
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
    "application/vnd.rar" = archive;
    "application/vnd.stardivision.calc" = excel;
    "application/vnd.stardivision.draw" = draw;
    "application/vnd.stardivision.impress" = powerpoint;
    "application/vnd.stardivision.math" = math;
    "application/vnd.stardivision.writer" = word;
    "application/vnd.sun.xml.base" = base;
    "application/vnd.sun.xml.calc" = excel;
    "application/vnd.sun.xml.calc.template" = excel;
    "application/vnd.sun.xml.draw" = draw;
    "application/vnd.sun.xml.draw.template" = draw;
    "application/vnd.sun.xml.impress" = powerpoint;
    "application/vnd.sun.xml.impress.template" = powerpoint;
    "application/vnd.sun.xml.math" = math;
    "application/vnd.sun.xml.writer" = word;
    "application/vnd.sun.xml.writer.global" = word;
    "application/vnd.sun.xml.writer.template" = word;
    "application/vnd.wordperfect" = word;
    "application/x-7z-compressed" = archive;
    "application/x-arj" = archive;
    "application/x-bittorrent" = torrent;
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
    "application/gzip" = archive;
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
    "application/x-xz" = archive;
    "application/x-xz-compressed-tar" = archive;
    "application/x-zoo" = archive;
    "application/x-zstd-compressed-tar" = archive;
    "application/zip" = archive;
    "application/zstd" = archive;
    "application/xhtml+xml" = browser;
    "application/xml" = editor;
    "audio/*" = video;
    "image/*" = image;
    "image/avif" = image;
    "image/bmp" = image;
    "image/gif" = image;
    "image/heic" = image;
    "image/heif" = image;
    "image/jpeg" = image;
    "image/jpg" = image;
    "image/jxl" = image;
    "image/pjpeg" = image;
    "image/png" = image;
    "image/svg+xml" = svg;
    "image/tiff" = image;
    "image/webp" = image;
    "image/x-compressed-xcf" = gimp;
    "image/x-fits" = gimp;
    "image/x-icb" = image;
    "image/x-ico" = image;
    "image/x-pcx" = image;
    "image/x-portable-anymap" = image;
    "image/x-portable-bitmap" = image;
    "image/x-portable-graymap" = image;
    "image/x-portable-pixmap" = image;
    "image/x-psd" = gimp;
    "image/x-xbitmap" = image;
    "image/x-xcf" = gimp;
    "image/x-xpixmap" = image;
    "image/x-xwindowdump" = image;
    "inode/directory" = fileManager;
    "message/rfc822" = mail;
    "text/*" = editor;
    "text/calendar" = mail;
    "text/csv" = excel;
    "text/html" = browser;
    "text/markdown" = editor;
    "text/plain" = editor;
    "video/*" = video;
    "x-scheme-handler/about" = browser;
    "x-scheme-handler/chrome" = browser;
    "x-scheme-handler/discord" = [ "discord.desktop" ]; # TODO: vesktop?
    "x-scheme-handler/ftp" = browser;
    "x-scheme-handler/http" = browser;
    "x-scheme-handler/https" = browser;
    "x-scheme-handler/magnet" = torrent;
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
