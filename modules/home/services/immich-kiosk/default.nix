{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.services.immich-kiosk;
in
{

  options.${namespace}.services.immich-kiosk = {
    enable = mkEnableOption "Whether or not to configure immich-kiosk.";
    subDomain = mkOpt types.str "kiosk" "The subdomain immich-kiosk is served on";
  };

  config = mkIf cfg.enable {
    sops.secrets = {
      "immich-kiosk-api-key-env".sopsFile = lib.snowfall.fs.get-file "secrets/daf/immich-kiosk.yaml";
      "immich-kiosk-albums-key-env".sopsFile = lib.snowfall.fs.get-file "secrets/daf/immich-kiosk.yaml";
      "immich-kiosk-weather-api-key-env".sopsFile =
        lib.snowfall.fs.get-file "secrets/daf/immich-kiosk.yaml";
    };

    nps.stacks.immich-kiosk = {
      enable = true;

      # KIOSK_IMMICH_API_KEY / KIOSK_ALBUMS (env-formatted sops secrets)
      environmentFiles = [
        config.sops.secrets."immich-kiosk-api-key-env".path
        config.sops.secrets."immich-kiosk-albums-key-env".path
      ];
      weatherApiKeyFile = config.sops.secrets."immich-kiosk-weather-api-key-env".path;

      containers.immich-kiosk = {
        expose = true;
        traefik = {
          inherit (cfg) subDomain;
          middleware.authelia.enable = true;
        };
        environment = {
          LANG = "fr_FR";
          TZ = "Europe/Paris";
        };
      };

      customCss = builtins.readFile ./custom.css;

      settings = {
        ## Clock
        show_time = true;
        time_format = 24;
        show_date = true;
        date_format = "DDDD DD MMMM YYYY";
        clock_source = "client";

        ## Kiosk behaviour
        duration = 60; # in seconds
        disable_screensaver = true; # ask browser to prevent screens from dimming or locking
        optimize_images = true; # resize images to the browser screen dimensions
        use_gpu = true;

        ## Asset sources
        show_archived = false;
        require_all_people = false;
        # album ids come from KIOSK_ALBUMS (sops)
        album_order = "random"; # random | newest | oldest
        memories = false;

        ## UI
        disable_ui = false;
        frameless = false;
        hide_cursor = false;
        font_size = 100; # percentage, without the % character
        background_blur = true;
        background_blur_amount = 10;
        theme = "fade"; # fade | solid
        layout = "single"; # single | splitview | splitview-landscape | portrait | landscape

        ## Sleep mode
        sleep_start = 23;
        sleep_end = 7;
        sleep_dim_screen = true; # only works with Fully Kiosk Browser
        sleep_icon = true;

        ## Transition options
        transition = "cross-fade"; # cross-fade | fade | none
        fade_transition_duration = 1; # in seconds
        cross_fade_transition_duration = 1; # in seconds

        ## Image display settings
        show_progress_bar = true;
        image_fit = "contain"; # none | contain | cover
        image_effect = "zoom"; # none | zoom | smart-zoom
        image_effect_amount = 120;
        use_original_image = false;

        ## Image metadata
        show_owner = false;
        show_album_name = true;
        show_person_name = true;
        show_person_age = false;
        show_image_time = false;
        image_time_format = 24;
        show_image_date = false;
        image_date_format = "DD-MM-YYYY";
        show_image_description = true;
        show_image_exif = false;
        show_image_location = true;
        show_image_qr = false;
        show_image_id = false;
        show_more_info = true;
        show_more_info_image_link = true;
        show_more_info_qr_code = true;

        like_button_action = "favorite"; # album, favorite or both
        hide_button_action = "tag"; # tag, archive or both

        ## Weather (API key comes from weatherApiKeyFile).
        ## Since kiosk 0.41 this is an object with a `locations` list, no
        ## longer a bare list of locations.
        weather.locations = [
          {
            name = "nanterre";
            lat = 48.8913;
            lon = 2.2005;
            unit = "metric";
            lang = "fr";
            forecast = true;
            default = true;
          }
          {
            name = "lamnay";
            lat = 48.1160;
            lon = 0.7033;
            unit = "metric";
            lang = "fr";
            forecast = true;
            default = false;
          }
        ];

        ## Options that can NOT be changed via url params
        kiosk = {
          port = 3000;
          behind_proxy = false;
          watch_config = false;
          fetched_assets_size = 1000;
          http_timeout = 20;
          cache = true; # cache select api calls
          prefetch = true; # fetch assets in the background
          asset_weighting = true; # use weighting when picking assets
        };
      };
    };
  };
}
