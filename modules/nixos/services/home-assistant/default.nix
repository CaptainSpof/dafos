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

  # Custom components must be built against the same interpreter/package set as
  # the home-assistant package itself (this is what buildHomeAssistantComponent
  # uses internally). Never hardcode pkgs.pythonXYPackages here — it silently
  # splits the package set the day HA moves to a new interpreter.
  hassPythonPkgs = pkgs.home-assistant.python3Packages;

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

    systemd.services.zigbee2mqtt = {
      serviceConfig = {
        Restart = mkForce "always";
        EnvironmentFile = config.sops.secrets."zigbee2mqtt-auth-token-env".path;
      };

      # The launcher (index.js:14) supervises the z2m process itself: on an
      # unsolicited stop it restarts the child after the next delay in this
      # list, which is a CSV of MINUTES. Setting it through
      # environment.sessionVariables never reached the service at all — and
      # would have been fatal if it had, because sessionVariables joins a list
      # with colons and the launcher rejects anything but comma-separated
      # digits with `process.exit(1)`.
      environment.Z2M_WATCHDOG = "0.5,3,6,15,30";
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

        # The three entries marked "discovered on the LAN" are not used
        # directly: zeroconf/bluetooth discovery kept trying to open a config
        # flow for them and failing with `No module named ...` on every start
        # (homekit_controller alone was ~30 tracebacks per boot). Building them
        # in is what makes the discovery flow work instead of erroring.
        extraComponents = [
          # "apple_tv"
          "androidtv_remote" # discovered on the LAN
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
          "homekit_controller" # discovered on the LAN
          "ibeacon"
          "ipp"
          "isal"
          "improv_ble"
          "ld2410_ble"
          "led_ble" # discovered on the LAN
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

        # `isal` is already in extraComponents and its manifest requires the
        # isal python package, so the module pulls it in on its own.

        customComponents = with pkgs.home-assistant-custom-components; [
          average
          alarmo
          adaptive_lighting
          # nixpkgs' auth_oidc runs `npm run css` to build the login page
          # stylesheet, which a hand-rolled dontBuild derivation skips.
          auth_oidc
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
            # inputs.hass-tapo-control is unpinned, so keep this in sync with
            # the version in the source's manifest.json after an input bump.
            version = "7.1.25";
            src = inputs.hass-tapo-control;
            dontConfigure = true;
            dontBuild = true;
            doCheck = false;

            # manifest.json pins `pytapo==3.4.18`, which nixpkgs currently
            # ships; if an upstream bump moves that pin ahead of nixpkgs,
            # manifestRequirementsCheckHook will fail the build and an
            # overrideAttrs on pytapo goes here.
            propagatedBuildInputs = with hassPythonPkgs; [
              pytapo
              aiohttp
              requests
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
