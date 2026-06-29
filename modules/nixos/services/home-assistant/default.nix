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
        # tapo_control 7.0.12 pins pytapo==3.4.15 in its manifest; keep this in
        # sync or the component's manifestCheckPhase fails the HA build.
        version = "3.4.15";
        src = pkgs.fetchPypi {
          pname = "pytapo";
          inherit version;
          hash = "sha256-2hC/MccVar7Xce5TL26qwVMrFQ+bxngiCitNx08Sz3E=";
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
    serialPort =
      mkOpt types.str
        "/dev/serial/by-id/usb-ITEAD_SONOFF_Zigbee_3.0_USB_Dongle_Plus_V2_20230803143100-if00"
        "The serial port to use with ZHA.";
    serialPortZigbee2Mqtt =
      mkOpt types.str "tcp://192.168.0.100:6638"
        "The serial port to use with Zigbee2mqtt.";
  };

  config = mkIf cfg.enable {

    dafos.user.extraGroups = [ "hass" ];

    environment.systemPackages = with pkgs; [
      zlib-ng
      home-assistant-cli
    ];

    # systemd.services.partOf = {
    #   zigbee2mqtt = [ "home-assistant.service" ];
    #   requiredBy = [ "home-assistant.service" ];
    # };

    systemd.services.zigbee2mqtt.serviceConfig = {
      # WatchdogSec = "30s";
      Restart = mkForce "always";
      # RestartSec = "10s";
    };

    services = {
      mosquitto = {
        enable = true;
        listeners = [
          {
            acl = [ "pattern readwrite #" ];
            omitPasswordAuth = true;
            settings.allow_anonymous = true;
          }
        ];
      };

      esphome = {
        enable = true;
        address = "0.0.0.0";
        port = 6052;
      };

      zigbee2mqtt = {
        enable = true;
        settings = {
          homeassistant.enabled = config.services.home-assistant.enable;
          availability = true;
          advanced.transmit_power = 20;
          permit_join = true;
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
          pkgs.dafos.lovelace-layout-card
          template-entity-row
          universal-remote-card
          vacuum-card
          weather-chart-card
          weather-card
        ];

        config = {
          default_config = { };

          http = {
            use_x_forwarded_for = true;
            trusted_proxies = [
              "10.80.0.1"
              "192.168.0.10"
              "127.0.0.1"
            ];
            server_host = [
              "0.0.0.0"
              "::"
            ];
          };

          bluetooth = { };
          smartir = { };

          homeassistant = {
            name = "MaisonDaf";
            unit_system = "metric";
            temperature_unit = "C";
          };

          lovelace.mode = "yaml";

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
          ] ++ (import ./sensors/sensors.nix);

          zha.zigpy_config.device = cfg.serialPort;
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
        80
        443
        8090
        8123
      ];
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/hass 0775 hass hass -"
      "d /var/lib/hass/pixelart 0775 hass hass -"
      "d /var/lib/hass/scripts 0775 hass hass -"
      "d /var/lib/hass/custom_templates 0775 hass hass -"
    ];
  };
}
