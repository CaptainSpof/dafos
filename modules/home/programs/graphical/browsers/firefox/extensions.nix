{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.dafos) mkOpt;

  cfg = config.dafos.programs.graphical.browsers.firefox;
in
{
  options.dafos.programs.graphical.browsers.firefox = {
    extensions = {

      packages = mkOpt (with lib.types; listOf package) (with pkgs.firefoxAddons; [
        adnauseam
        adguard-adblocker
        adaptive-tab-bar-colour
        absolute-enable-right-click
        auto-tab-discard
        bitwarden-password-manager
        consent-o-matic
        darkreader
        dearrow
        downthemall
        modern-for-wikipedia
        # enhancer-for-youtube
        firefox-color
        flagfox
        frankerfacez
        # french-language-pack
        # fx_cast
        karakeep
        languagetool
        org-capture # TODO: setup
        plasma-integration
        pywalfox
        qwant-search
        reddit-enhancement-suite
        refined-github-
        return-youtube-dislikes
        new-tab-override
        simple-tab-groups
        sponsorblock
        stylus
        tridactyl-vim
        # ublock-origin
        ugetintegration
        user-agent-string-switcher
        view-image
        violentmonkey
        youtube-addon
      ]) "Extensions to install";

      settings = mkOpt (with lib.types; attrsOf anything) {
        "uBlock0@raymondhill.net" = {
          # Home-manager skip collision check
          force = true;
          settings = {
            selectedFilterLists = [
              "easylist"
              "easylist-annoyances"
              "easylist-chat"
              "easylist-newsletters"
              "easylist-notifications"
              "fanboy-cookiemonster"
              "ublock-badware"
              "ublock-cookies-easylist"
              "ublock-filters"
              "ublock-privacy"
              "ublock-quick-fixes"
              "ublock-unbreak"
            ];
          };
        };
      } "Settings to apply to the extensions.";

    };
  };

  config = lib.mkIf cfg.enable {
    programs.firefox.profiles.${config.dafos.user.name}.extensions = {
      inherit (cfg.extensions) packages settings;
      force = cfg.extensions.settings != { };
    };
  };
}
