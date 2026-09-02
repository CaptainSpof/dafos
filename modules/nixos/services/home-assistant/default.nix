{
  config,
  lib,
  pkgs,
  namespace,
  inputs,
  ...
}:

let
  inherit (lib) mkIf types mkForce;
  inherit (lib.${namespace}) mkOpt mkBoolOpt;

  cfg = config.${namespace}.services.home-assistant;

  customPythonPkgs = pkgs.python314Packages.override {
    overrides = _self: super: {
      pytapo = super.pytapo.overrideAttrs (_oldAttrs: rec {
        # tapo_control pins an exact pytapo version in its manifest; keep this in
        # sync or the component's manifestCheckPhase fails the HA build.
        # (inputs.hass-tapo-control is unpinned, so upstream bumps surface here.)
        version = "3.4.18";
        src = pkgs.fetchPypi {
          pname = "pytapo";
          inherit version;
          hash = "sha256-N8s4L8quSWlChU4BSKnLDqY6WboJbcuYLNaFwPEeNnI=";
        };
        propagatedBuildInputs = with pkgs.python314Packages; [
          aiohttp
          pycryptodome
          requests
          python-kasa
          rtp
          urllib3
        ];
      });
    };
  };

in
{
  options.${namespace}.services.home-assistant = {
    enable = mkBoolOpt false "Whether or not to enable home-assistant.";
    serialPortZigbee2Mqtt =
      mkOpt types.str "tcp://192.168.0.100:6638"
        "The serial port to use with Zigbee2mqtt.";
  };

  config = mkIf cfg.enable {

    dafos.user.extraGroups = [ "hass" ];

    environment.systemPackages = with pkgs; [
      zlib-ng
      home-assistant-cli
      esphome
    ];

    # The zigbee2mqtt frontend is admin-equivalent (pair, remove, OTA, MQTT
    # passthrough), so give it a token of its own rather than relying purely on
    # Traefik. It is passed as an env override instead of `settings.frontend
    # .auth_token` because the module renders `settings` into the world-readable
    # nix store. systemd reads EnvironmentFile as root, before dropping privileges.
    sops.secrets."zigbee2mqtt-auth-token-env".sopsFile =
      lib.snowfall.fs.get-file "secrets/daf/zigbee2mqtt.yaml";

    systemd.services.zigbee2mqtt.serviceConfig = {
      # WatchdogSec = "30s";
      Restart = mkForce "always";
      # RestartSec = "10s";
      EnvironmentFile = config.sops.secrets."zigbee2mqtt-auth-token-env".path;
    };

    services = {
      mosquitto = {
        enable = true;
        listeners = [
          {
            address = "127.0.0.1";
            acl = [ "pattern readwrite #" ];
            omitPasswordAuth = true;
            settings.allow_anonymous = true;
          }
        ];
      };

      esphome.enable = false;

      zigbee2mqtt = {
        enable = true;
        settings = {
          homeassistant.enabled = config.services.home-assistant.enable;
          availability = true;
          advanced.transmit_power = 20;
          mqtt = {
            server = "mqtt://127.0.0.1:1883";
            base_topic = "zigbee2mqtt";
          };
          frontend.port = 8090;
          serial = {
            adapter = "zstack";
            baudrate = 115200;
            port = cfg.serialPortZigbee2Mqtt;
          };
        };
      };

      home-assistant = {
        enable = true;

        extraComponents = [
          # "apple_tv"
          "backup"
          "bluetooth"
          "bluetooth_adapters"
          # "bluetooth_tracker"
          "broadlink"
          "camera"
          "cast"
          "esphome"
          "forked_daapd"
          "freebox"
          "google"
          "google_translate"
          "google_tasks"
          "ibeacon"
          "ipp"
          "isal"
          "improv_ble"
          "ld2410_ble"
          "local_calendar"
          "mealie"
          "met"
          "meteo_france"
          "mobile_app"
          "mqtt"
          "netatmo"
          "onvif"
          "openai_conversation"
          "ollama"
          "radarr"
          "roborock"
          "samsungtv"
          "smartthings"
          "smlight"
          "sonarr"
          "kegtron"
          "tailscale"
          "telegram"
          "telegram_bot"
          "tplink"
          # "tuya"
          "wled"
          "xiaomi_ble"
          "yeelight"
          "zha"
        ];

        extraPackages =
          ps: with ps; [
            isal
          ];

        customComponents = with pkgs.home-assistant-custom-components; [
          average
          alarmo
          adaptive_lighting
          better_thermostat
          # frigate
          samsungtv-smart
          smartir
          spook
          # tuya_local
          # localtuya
          # pkgs.dafos.hass-divoom
          (pkgs.buildHomeAssistantComponent {
            owner = "JurajNyiri";
            domain = "tapo_control";
            version = "7.0.12";
            src = inputs.hass-tapo-control;
            dontConfigure = true;
            dontBuild = true;
            doCheck = false;

            propagatedBuildInputs = [
              customPythonPkgs.pytapo
              # pkgs.python313Packages.pytapo
              pkgs.python314Packages.aiohttp
              pkgs.python314Packages.requests
            ];
          })
          (pkgs.buildHomeAssistantComponent {
            owner = "christiaangoossens";
            domain = "auth_oidc";
            version = "1.1.1";
            src = inputs.hass-oidc-auth;
            dontConfigure = true;
            dontBuild = true;
            doCheck = false;

            propagatedBuildInputs = with pkgs.python314Packages; [
              joserfc
              aiofiles
              jinja2
            ];
          })
          # Companion integration for the lovelace-idf-mobilite card (config-flow,
          # UI setup). manifest.json lists no requirements (aiohttp/voluptuous are
          # already core HA deps), and it's a content_in_root layout which
          # buildHomeAssistantComponent handles via the root manifest.json.
          (pkgs.buildHomeAssistantComponent {
            owner = "yyrkoon94";
            domain = "idf_mobilite_assistant";
            version = "0.1.0";
            src = inputs.idf-mobilite-assistant;
            dontConfigure = true;
            dontBuild = true;
            doCheck = false;
          })
        ];

        customLovelaceModules = with pkgs.home-assistant-custom-lovelace-modules; [
          advanced-camera-card
          atomic-calendar-revive
          bubble-card
          button-card
          card-mod
          decluttering-card
          hourly-weather
          light-entity-card
          mini-graph-card
          mini-media-player
          multiple-entity-row
          mushroom
          pkgs.dafos.custom-brand-icons
          pkgs.dafos.lovelace-auto-entities
          pkgs.dafos.lovelace-fold-entity-row
          pkgs.dafos.lovelace-idf-mobilite
          pkgs.dafos.lovelace-layout-card
          template-entity-row
          universal-remote-card
          vacuum-card
          weather-chart-card
          weather-card
        ];

        config = {
          default_config = { };

          # No `http:` block on purpose. HA 2026.8 migrated http config into
          # .storage/http and now ignores YAML entirely — leaving the block in
          # only raised the `yaml_still_present_after_migration` repair. The
          # reverse-proxy settings (use_x_forwarded_for + the Traefik/Tailscale
          # trusted_proxies) were migrated on 2026-08-18 and are now managed in
          # Settings > System > Network.

          smartir = { };

          # OIDC/SSO login via Authelia (github.com/christiaangoossens/hass-oidc-auth).
          # Public client + PKCE, so no client_secret. Access is gated on the
          # `home-assistant_user` lldap group by an Authelia authorization policy;
          # `lldap_admin` members additionally become HA admins.
          auth_oidc = {
            client_id = "home-assistant";
            discovery_url = "https://auth.daftdaf.dev/.well-known/openid-configuration";
            display_name = "MaisonDaf SSO";
            features.automatic_person_creation = true;
            claims = {
              username = "preferred_username";
              display_name = "name";
              groups = "groups";
            };
            roles = {
              admin = "lldap_admin";
              user = "home-assistant_user";
            };
          };

          homeassistant = {
            name = "MaisonDaf";
            unit_system = "metric";
            temperature_unit = "C";
          };

          lovelace.dashboards.lovelace = {
            title = "Overview";
            icon = "mdi:view-dashboard";
            show_in_sidebar = true;
            require_admin = false;
            mode = "yaml";
            filename = "ui-lovelace.yaml";
          };

          "automation manual" = [ ];
          "automation ui" = "!include automations.yaml";
          "scene ui" = "!include scenes.yaml";
          "script ui" = "!include_dir_merge_named scripts/";

          "template" = [
            {
              trigger = [
                {
                  trigger = "event";
                  event_type = "bubble_card_update_modules";
                }
              ];
              sensor = [
                {
                  name = "Bubble Card Modules";
                  state = "saved";
                  icon = "mdi:puzzle";
                  attributes = {
                    modules = "{{ trigger.event.data.modules }}";
                    last_updated = "{{ trigger.event.data.last_updated }}";
                  };
                }
              ];
            }
            # Template binary sensors + sensors migrated from the legacy
            # `binary_sensor:`/`sensor: - platform: template` format that HA
            # 2026.6 removed. They now live under the modern `template:`
            # integration as separate blocks.
            { binary_sensor = import ./sensors/binary_sensors.nix; }
            { sensor = import ./sensors/template_sensors.nix; }
          ];

          input_boolean = import ./sensors/input_booleans.nix;
          input_text = import ./sensors/input_texts.nix;
          sensor = [
            {
              platform = "time_date";
              display_options = [
                "time"
                "date"
                "date_time"
                "date_time_utc"
                "date_time_iso"
                "time_date"
                "time_utc"
              ];
            }
          ]
          ++ (import ./sensors/sensors.nix);

          # No `zha:` block: ZHA is config-flow only. It reads the coordinator
          # from the config entry and `create_zha_config` overwrites whatever
          # YAML put in zigpy_config.device, so setting it here did nothing.
          # The local SONOFF dongle is ZHA's; zigbee2mqtt drives the separate
          # network on the remote zstack coordinator (serialPortZigbee2Mqtt).
        };
      };
    };

    # Zigbee2mqtt: enable watchdog
    environment.sessionVariables = {
      Z2M_WATCHDOG = [
        "0.5"
        "3"
        "6"
        "15"
        "30"
      ];
    };

    networking.firewall = {
      allowedTCPPorts = [
        8123
      ];
    };

    # NOTE: the mode on /var/lib/hass itself is not actually 0775 — it is the
    # hass user's home and `createHome` re-chmods it to 0700 on every
    # activation, after tmpfiles has run. Combined with the unit's UMask=0077
    # that also makes `dafos.user.extraGroups = [ "hass" ]` above a no-op. To
    # genuinely give daf read access it would take
    # `users.users.hass.homeMode = "750"` plus a UMask override, which is a
    # deliberate weakening of upstream's hardening — left alone for now. The
    # two subdirectories are still worth creating; HA needs them to exist.
    systemd.tmpfiles.rules = [
      "d /var/lib/hass/scripts 0775 hass hass -"
      "d /var/lib/hass/custom_templates 0775 hass hass -"
    ];
  };
}
