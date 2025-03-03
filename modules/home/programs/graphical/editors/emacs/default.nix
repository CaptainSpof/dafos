{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib) mkIf types;
  inherit (lib.${namespace}) mkOpt mkBoolOpt;

  cfg = config.${namespace}.programs.graphical.editors.emacs;
in
{
  options.${namespace}.programs.graphical.editors.emacs = {
    enable = mkBoolOpt false "Whether or not to enable emacs.";
    latex.enable = mkBoolOpt false "Whether or not to enable latex support for emacs.";
    package = mkOpt types.package pkgs.emacs-unstable-pgtk "The emacs package to be used.";
  };

  config = mkIf cfg.enable {

    services.emacs = {
      enable = true;
      inherit (cfg) package;
    };

    programs.emacs = {
      enable = true;
      inherit (cfg) package;
      extraPackages =
        epkgs: with epkgs; [
          jinx
          pdf-tools
          sqlite3
          vterm
        ];
    };

    xdg.desktopEntries.org-protocol = {
      name = "org-protocol";
      exec = "emacsclient -- %u";
      terminal = false;
      type = "Application";
      categories = [ "System" ];
      mimeType = [ "x-scheme-handler/org-protocol" ];
    };

    home = {
      packages =
        with pkgs;
        [
          (aspellWithDicts (
            ds: with ds; [
              en
              en-computers
              en-science
              fr
            ]
          ))
          djvu2pdf
          enchant
          ffmpegthumbnailer
          hunspellDicts.en-us
          hunspellDicts.fr-any
          languagetool
          mediainfo
          nuspell
          poppler
          sqlite
        ]
        ++ lib.optionals cfg.latex.enable [ texlive.combined.sheme-full ];

      sessionPath = [ "$XDG_CONFIG_HOME/emacs/bin" ];
      shellAliases = {
        "ne" = "emacsclient -nw";
      };
    };
  };
}
