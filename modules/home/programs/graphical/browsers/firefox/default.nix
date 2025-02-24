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

  firefoxPath = ".mozilla/firefox/${config.${namespace}.user.name}";
in
{
  options.${namespace}.programs.graphical.browsers.firefox = with types; {
    enable = mkBoolOpt false "Whether or not to enable firefox.";

    extensions = {
      packages = mkOpt (listOf package) (with pkgs.nur.repos.rycee.firefox-addons; [
        absolute-enable-right-click
        auto-tab-discard
        bitwarden
        # consent-o-matic
        darkreader
        dearrow
        downthemall
        enhancer-for-youtube
        firefox-color
        flagfox
        french-language-pack
        fx_cast
        languagetool
        org-capture # TODO: setup
        plasma-integration
        reddit-enhancement-suite
        refined-github
        return-youtube-dislikes
        simple-tab-groups
        sponsorblock
        stylus
        tridactyl
        ublock-origin
        user-agent-string-switcher
        view-image
        violentmonkey
      ]) "Extensions to install";
    };

    extraConfig = mkOpt str "" "Extra configuration for the user profile JS file.";

    package = mkOpt types.package pkgs.firefox "The firefox package to be used.";

    policies = mkOpt attrs {
      CaptivePortal = false;
      DisableFirefoxStudies = true;
      DisableFormHistory = true;
      DisablePocket = true;
      DisableTelemetry = true;
      DisplayBookmarksToolbar = true;
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

        "tridactyl".installation_mode = "force_installed";

        "frankerfacez@frankerfacez.com" = {
          installation_mode = "force_installed";
          install_url = "https://cdn.frankerfacez.com/script/frankerfacez-4.0-an+fx.xpi";
        };

        "magnolia_limited_permissions@12.34" = {
          installation_mode = "force_installed";
          install_url = "https://gitlab.com/magnolia1234/bpc-uploads/-/raw/master/bypass_paywalls_clean-3.2.3.0-custom.xpi";
        };

        "ATBC@EasonWong" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/file/4159211/adaptive_tab_bar_colour-2.1.4.xpi";
        };
      };
      Preferences = { };
    } "Policies to apply to firefox";

    search = mkOpt attrs {
      default = "Google";
      privateDefault = "DuckDuckGo";
      force = true;

      engines = {

        "Nix Issues" = {
          icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
          definedAliases = [
            "ni"
            "@ni"
          ];
          urls = [
            {
              template = "https://github.com/NixOS/nixpkgs/issues";
              params = [
                {
                  name = "q";
                  value = "{searchTerms}";
                }
              ];
            }
          ];
        };

        "Nix Packages" = {
          icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
          definedAliases = [
            "n"
            "@n"
          ];
          urls = [
            {
              template = "https://search.nixos.org/packages";
              params = [
                {
                  name = "type";
                  value = "packages";
                }
                {
                  name = "channel";
                  value = "unstable";
                }
                {
                  name = "query";
                  value = "{searchTerms}";
                }
              ];
            }
          ];
        };

        "NixOS Options" = {
          icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
          definedAliases = [
            "no"
            "@no"
          ];
          urls = [
            {
              template = "https://search.nixos.org/options";
              params = [
                {
                  name = "channel";
                  value = "unstable";
                }
                {
                  name = "query";
                  value = "{searchTerms}";
                }
              ];
            }
          ];
        };

        "GitHub" = {
          iconUpdateURL = "https://github.com/favicon.ico";
          updateInterval = 24 * 60 * 60 * 1000;
          definedAliases = [
            "gh"
            "@gh"
          ];

          urls = [
            {
              template = "https://github.com/search";
              params = [
                {
                  name = "q";
                  value = "{searchTerms}";
                }
              ];
            }
          ];
        };

        "Home Manager Options" = {
          icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
          definedAliases = [
            "hm"
            "@hm"
          ];
          urls = [
            {
              template = "https://home-manager-options.extranix.com";
              params = [
                {
                  name = "query";
                  value = "{searchTerms}";
                }
                {
                  name = "release";
                  value = "master";
                }
              ];
            }
          ];
        };
      };
    } "Search configuration";

    gpuAcceleration = mkBoolOpt false "Enable GPU acceleration.";
    hardwareDecoding = mkBoolOpt false "Enable hardware video decoding.";
    settings = mkOpt attrs { } "Settings to apply to the profile.";
    userChrome = mkOpt str "" "Extra configuration for the user chrome CSS file.";
  };

  config = mkIf cfg.enable {
    home = {
      file = mkMerge [
        # Fix tridactyl & plasma integration
        {
          "${firefoxPath}/native-messaging-hosts".source = pkgs.symlinkJoin {
            name = "native-messaging-hosts";
            paths = [
              "${pkgs.kdePackages.plasma-browser-integration}/lib/mozilla/native-messaging-hosts"
              "${pkgs.tridactyl-native}/lib/mozilla/native-messaging-hosts"
            ];

            recursive = true;
          };
          # "${firefoxPath}/chrome/" = {
          #   source = lib.cleanSourceWith { src = lib.cleanSource ./chrome/.; };

          #   recursive = true;
          # };
        }
      ];
    };

    # Tridactyl
    xdg.configFile."tridactyl/tridactylrc".source = ./tridactyl/tridactylrc;
    xdg.configFile."tridactyl/themes/everforest-dark.css".source =
      ./tridactyl/tridactyl_style_everforest.css;

    home.packages = with pkgs; [
      fx-cast-bridge
    ];

    programs.firefox = {
      enable = true;

      inherit (cfg) policies;

      package = cfg.package.override (orig: {
        nativeMessagingHosts = (orig.nativeMessagingHosts or [ ]) ++ [
          pkgs.tridactyl-native
          pkgs.kdePackages.plasma-browser-integration
          pkgs.fx-cast-bridge
        ];
      });

      profiles.${config.${namespace}.user.name} = {
        inherit (cfg) extraConfig extensions search;
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
                "dearrow_ajay_app-browser-action"
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

            "sidebar.verticalTabs" = true;
            "browser.tabs.inTitlebar" = 0;
            "browser.theme.content-theme" = 0;
            "browser.theme.toolbar-theme" = 0;
            "extensions.activeThemeID" = "firefox-compact-dark@mozilla.org";

            "font.name.monospace.x-western" = "MonaspiceKr Nerd Font";
            "font.name.sans-serif.x-western" = "MonaspiceNe Nerd Font";
            "font.name.serif.x-western" = "MonaspiceNe Nerd Font";
            "toolkit.legacyUserProfileCustomizations.stylesheets" = true;

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
            "intl.accept_languages" = "en-US,en";

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

        inherit (cfg) userChrome;
      };
    };
  };
}
