{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib)
    mkIf
    mkMerge
    optionalAttrs
    types
    ;
  inherit (lib.${namespace}) mkBoolOpt mkOpt;

  cfg = config.${namespace}.programs.graphical.browsers.firefox;
in
{
  imports = lib.snowfall.fs.get-non-default-nix-files ./.;

  options.${namespace}.programs.graphical.browsers.firefox = with types; {
    enable = mkBoolOpt true "Whether or not to enable firefox.";

    extraConfig = mkOpt str "" "Extra configuration for the user profile JS file.";
    gpuAcceleration = mkBoolOpt false "Enable GPU acceleration.";
    hardwareDecoding = mkBoolOpt false "Enable hardware video decoding.";

    package = mkOpt types.package pkgs.firefox "The firefox package to be used.";

    policies = mkOpt attrs {
      CaptivePortal = false;
      DisableFirefoxStudies = true;
      DisableFormHistory = true;
      DisablePocket = true;
      DisableTelemetry = true;
      DisplayBookmarksToolbar = false;
      DontCheckDefaultBrowser = true;
      FirefoxHome = {
        Pocket = false;
        Snippets = false;
      };

      PasswordManagerEnabled = false;
      PromptForDownloadLocation = true;

      UserMessaging = {
        ExtensionRecommendations = false;
        SkipOnboarding = true;
      };

      ExtensionSettings = {
        "ebay@search.mozilla.org".installation_mode = "blocked";
        "amazondotcom@search.mozilla.org".installation_mode = "blocked";
        "bing@search.mozilla.org".installation_mode = "blocked";
        "ddg@search.mozilla.org".installation_mode = "blocked";
        "wikipedia@search.mozilla.org".installation_mode = "blocked";
        # Tridactyl is installed declaratively via firefox.extensions.packages
        # (tridactyl-vim), so no force_installed policy is needed here.
      };
      Preferences = { };
    } "Policies to apply to firefox";

    settings = mkOpt attrs { } "Settings to apply to the profile.";
    userChrome = mkOpt str "" "Extra configuration for the user chrome CSS file.";
  };

  config = mkIf cfg.enable {
    # Native messaging hosts (tridactyl, plasma, fx-cast, …) are installed into
    # ~/.mozilla/native-messaging-hosts by home-manager via the
    # `programs.firefox.nativeMessagingHosts` list below.

    # Tridactyl
    xdg.configFile."tridactyl/tridactylrc".source = ./tridactyl/tridactylrc;
    xdg.configFile."tridactyl/themes/everforest-dark.css".source =
      ./tridactyl/tridactyl_style_everforest.css;

    home.packages = with pkgs; [
      fx-cast-bridge
      pywalfox-native
    ];

    home.sessionVariables = {
      MOZ_USE_XINPUT2 = "1";
    };

    programs.firefox = {
      enable = true;

      inherit (cfg) package;

      # Pin the legacy profile location (~/.mozilla/firefox). The HM default
      # moved to $XDG_CONFIG_HOME/mozilla/firefox in stateVersion 26.05;
      # keeping the old path avoids migrating the existing profile.
      configPath = ".mozilla/firefox";

      nativeMessagingHosts = [
        pkgs.tridactyl-native
        pkgs.kdePackages.plasma-browser-integration
        pkgs.fx-cast-bridge
        pkgs.uget-integrator
        pkgs.pywalfox-native
      ];

      inherit (cfg) policies;

      profiles.${config.${namespace}.user.name} = {
        inherit (cfg) extraConfig;
        inherit (config.${namespace}.user) name;

        id = 0;

        settings = mkMerge [
          cfg.settings
          {
            "accessibility.typeaheadfind.enablesound" = false;
            "accessibility.typeaheadfind.flashBar" = 0;

            "browser.aboutConfig.showWarning" = false;
            "browser.aboutwelcome.enabled" = false;
            "browser.bookmarks.autoExportHTML" = true;
            "browser.bookmarks.showMobileBookmarks" = true;
            "browser.contentblocking.category" = "strict";
            "browser.meta_refresh_when_inactive.disabled" = true;
            "browser.newtabpage.activity-stream.default.sites" = "";
            "browser.newtabpage.activity-stream.showSponsored" = false;
            "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;

            # Search
            "browser.search.suggest.enabled" = false;

            "browser.sessionstore.warnOnQuit" = true;
            "browser.shell.checkDefaultBrowser" = false;
            "browser.ssb.enabled" = true;
            "browser.startup.homepage.abouthome_cache.enabled" = true;
            "browser.startup.page" = 3;
            "browser.translations.neverTranslateLanguages" = "fr";
            "browser.urlbar.keepPanelOpenDuringImeComposition" = true;
            "browser.urlbar.suggest.quicksuggest.sponsored" = false;

            # UI
            "browser.uiCustomization.state" = builtins.toJSON {
              placements = {
                widget-overflow-fixed-list = [ ];
                unified-extensions-area = [ ];

                nav-bar = [
                  "sidebar-button"
                  "customizableui-special-spacer1"
                  "back-button"
                  "forward-button"
                  "stop-reload-button"
                  "customizableui-special-spring4"
                  "simple-tab-groups_drive4ik-browser-action"
                  "urlbar-container"
                  "_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action" # Bitwarden
                  "customizableui-special-spring5"
                  "downloads-button"

                  # Extensions
                  # "_testpilot-containers-browser-action"
                  "unified-extensions-button"
                ];

                toolbar-menubar = [ "menubar-items" ];

                TabsToolbar = [
                  "tabbrowser-tabs"
                  "simple-tab-groups_drive4ik-browser-action"
                ];

                PersonalToolbar = [
                  "import-button"
                  "personal-bookmarks"
                ];
              };

              seen = [
                "developer-button"

                # Extensions
                "_testpilot-containers-browser-action"
                "popupwindow_ettoolong-browser-action"
                "sponsorblocker_ajay_app-browser-action"
                "ublock0_raymondhill_net-browser-action"
                "adnauseam_rednoise_org-browser-action"
                "dearrow_ajay_app-browser-action"
                "_3c6bf0cc-3ae2-42fb-9993-0d33104fdcaf_-browser-action"
                "newtaboverride_agenedia_com-browser-action"
              ];

              dirtyAreaCache = [
                "nav-bar"
                "toolbar-menubar"
                "TabsToolbar"
                "PersonalToolbar"
                "unified-extensions-area"
              ];

              currentVersion = 20;
              newElementCount = 2;
            };

            "browser.ctrlTab.sortByRecentlyUsed" = true;
            "browser.tabs.inTitlebar" = 0;
            "browser.tabs.insertAfterCurrent" = true;
            "browser.tabs.insertRelatedAfterCurrent" = true;
            # Follow the OS color scheme (reported via the XDG Settings portal).
            "browser.theme.content-theme" = 2; # 0 = dark, 1 = light, 2 = follow system
            "browser.theme.toolbar-theme" = 2;

            "extensions.activeThemeID" = "default-theme@mozilla.org"; # System theme (follows OS)
            "extensions.autoDisableScopes" = 0;

            # Use the legacy JSON storage backend
            # (browser-extension-data/<id>/storage.js) instead of per-profile
            # IndexedDB, so Nix-managed extension settings
            # (firefox.extensions.settings: New Tab Override URL, AdNauseam
            # filter lists) are authoritative rather than shadowed by IDB.
            "extensions.webextensions.ExtensionStorageIDB.enabled" = false;

            "font.name.monospace.x-western" = "MonaspiceKr Nerd Font";
            "font.name.sans-serif.x-western" = "MonaspiceNe Nerd Font";
            "font.name.serif.x-western" = "MonaspiceNe Nerd Font";
            "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
            "svg.context-properties.content.enabled" = true;
            "userChrome.theme-material" = true;

            "devtools.chrome.enabled" = true;
            "devtools.debugger.remote-enabled" = true;
            "dom.storage.next_gen" = true;
            "dom.forms.autocomplete.formautofill" = true;
            "extensions.htmlaboutaddons.recommendations.enabled" = false;
            "extensions.formautofill.addresses.enabled" = false;
            "extensions.formautofill.creditCards.enabled" = false;
            "general.autoScroll" = false;
            "general.smoothScroll.msdPhysics.enabled" = true;
            "geo.enabled" = false;
            "geo.provider.use_corelocation" = false;
            "geo.provider.use_geoclue" = false;
            "geo.provider.use_gpsd" = false;
            "intl.accept_languages" = "en-US,en,fr";

            "media.eme.enabled" = true;
            "media.videocontrols.picture-in-picture.video-toggle.enabled" = false;

            # Telemetry
            "app.shield.optoutstudies.enabled" = false;
            "browser.newtabpage.activity-stream.feeds.telemetry" = false;
            "browser.newtabpage.activity-stream.telemetry" = false;
            "browser.ping-centre.telemetry" = false;
            "datareporting.healthreport.uploadEnabled" = false;
            "datareporting.policy.dataSubmissionEnabled" = false;
            "dom.private-attribution.submission.enabled" = false;
            "dom.security.unexpected_system_load_telemetry_enabled" = false;
            "network.trr.confirmation_telemetry_enabled" = false;
            "security.app_menu.recordEventTelemetry" = false;
            "security.certerrors.recordEventTelemetry" = false;
            "security.identitypopup.recordEventTelemetry" = false;
            "security.protectionspopup.recordEventTelemetry" = false;
            "toolkit.telemetry.archive.enabled" = false;
            "toolkit.telemetry.bhrPing.enabled" = false;
            "toolkit.telemetry.enabled" = false;
            "toolkit.telemetry.firstShutdownPing.enabled" = false;
            "toolkit.telemetry.newProfilePing.enabled" = false;
            "toolkit.telemetry.reportingpolicy.firstRun" = false;
            "toolkit.telemetry.server" = "https://127.0.0.1";
            "toolkit.telemetry.shutdownPingSender.enabled" = false;
            "toolkit.telemetry.unified" = false;
            "toolkit.telemetry.updatePing.enabled" = false;

            "signon.autofillForms" = false;
            "signon.rememberSignons" = false;

            # Sidebar
            "sidebar.revamp" = true;
            "sidebar.verticalTabs" = true;
            # "sidebar.visibility" = "expand-on-hover";
            "browser.tabs.groups.smart.userEnabled" = false;

            "apz.overscroll.enabled" = true; # DEFAULT NON-LINUX
            "general.smoothScroll" = true; # DEFAULT
            "general.smoothScroll.msdPhysics.continuousMotionMaxDeltaMS" = 12;
            # "general.smoothScroll.msdPhysics.enabled" = true;
            "general.smoothScroll.msdPhysics.motionBeginSpringConstant" = 600;
            "general.smoothScroll.msdPhysics.regularSpringConstant" = 650;
            "general.smoothScroll.msdPhysics.slowdownMinDeltaMS" = 25;
            "general.smoothScroll.msdPhysics.slowdownMinDeltaRatio" = "2";
            "general.smoothScroll.msdPhysics.slowdownSpringConstant" = 250;
            "general.smoothScroll.currentVelocityWeighting" = "1";
            "general.smoothScroll.stopDecelerationWeighting" = "1";
            "mousewheel.default.delta_multiplier_y" = 300; # 250-400; adjust this number to your liking
          }
          (optionalAttrs cfg.gpuAcceleration {
            "dom.webgpu.enabled" = true;
            "gfx.webrender.all" = true;
            "layers.gpu-process.enabled" = true;
            "layers.mlgpu.enabled" = true;
          })
          (optionalAttrs cfg.hardwareDecoding {
            "media.av1.enabled" = true;
            "media.ffmpeg.vaapi.enabled" = true;
            "media.ffvpx.enabled" = false;
            "media.gpu-process-decoder" = true;
            "media.hardware-video-decoding.enabled" = true;
            "media.rdd-ffmpeg.enabled" = true;
            "media.rdd-vpx.enabled" = false;
            "widget.dmabuf.force-enabled" = true;
          })
        ];

        # inherit (cfg) userChrome;
      };
    };
  };
}
