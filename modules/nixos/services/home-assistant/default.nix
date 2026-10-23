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

  # Helpers of the Maison dashboard (Origami), generated from ./origami/rooms.nix.
  origami = import ./origami/helpers.nix { inherit lib; };
  # Which of the dashboard's entities are unavailable.
  offline = import ./origami/offline.nix { inherit lib; };

  # Kitchen and veranda air quality: detectors, level sensors and the airing
  # notifications.
  airQuality = import ./air_quality.nix { inherit lib; };

  # Colour panel statuses as dismissible notifications.
  statusNotices = import ./status_notices.nix { inherit lib; };

  # Canon TS9100 ink levels, read from its remote UI (IPP/SNMP report -2).
  printerInk = import ./printer_ink.nix { inherit lib pkgs; };

  # Appliance programme lengths, learned from their cycles.
  appliancePrograms = import ./appliance_programs.nix { inherit lib; };

  # dafspi's cycle as a Live Update notification.
  vacuumProgress = import ./vacuum_progress.nix { };

  # Stove against boiler: run signals, last runs and totals.
  heatingUsage = import ./heating_usage.nix { inherit lib; };

  # Reload, then restart HA when the Netatmo integration stays down.
  netatmoWatchdog = import ./netatmo_watchdog.nix { };
  divoom = import ./divoom/display.nix { inherit pkgs; };

  # Trigger sensors for the sensor-light automations.
  lightTriggers = import ./light_triggers.nix { };

  # Veranda TV start-up script.
  tv = import ./tv.nix { };

  # The desk's Aqara cube, read from its MQTT payload.
  deskCube = import ./desk_cube.nix { };

  # BILRESA Matter buttons (desk, veranda).
  bilresa = import ./bilresa.nix { };

  # Double presses of the RODRET switches.
  rodret = import ./rodret.nix { };

  # The single owner of the heating (valves, stove, Netatmo, boiler boosts).
  heatingController = import ./heating_controller.nix { };

  # Room thermometers driving the radiator valves.
  trvExternalSensors = import ./trv_external_sensors.nix { };

  # CO2 alerts (desk ALPSTUGA).
  co2 = import ./co2.nix { inherit lib; };

  # Pellet tank estimate and refill alert.
  pellets = import ./pellets.nix { };

  # Custom components must be built against the same interpreter/package set as
  # the home-assistant package itself (this is what buildHomeAssistantComponent
  # uses internally). Never hardcode pkgs.pythonXYPackages here — it silently
  # splits the package set the day HA moves to a new interpreter.
  hassPythonPkgs = pkgs.home-assistant.python3Packages;

  # tapo_control 7.1.27 pins `pytapo==3.4.19`; nixpkgs still ships 3.4.18, so
  # manifestRequirementsCheckHook fails the component build. 3.4.19 has the same
  # dependency set as 3.4.18 (requests, urllib3, pycryptodome, rtp, python-kasa),
  # so a version+src bump is enough. Drop this once nixpkgs catches up.
  pytapo = hassPythonPkgs.pytapo.overrideAttrs (old: rec {
    version = "3.4.19";
    src = pkgs.fetchPypi {
      inherit (old) pname;
      inherit version;
      hash = "sha256-iwF7f5pwcYFBw6mPQw2YgRIcElqrcTMpzGCNJsttJY8=";
    };
  });

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
    sops.secrets."zigbee2mqtt-auth-token-env" = {
      sopsFile = lib.snowfall.fs.get-file "secrets/dafoltop/zigbee2mqtt.yaml";
      # EnvironmentFile is only read at start, so a rotated token needs one.
      restartUnits = [ "zigbee2mqtt.service" ];
    };

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
          homeassistant = {
            enabled = config.services.home-assistant.enable;
            # An action sensor (sensor.<name>_action) per remote: the
            # lsismeiro controller blueprints read it for Zigbee2MQTT remotes
            # (ZHA → Z2M migration). Remotes wired before keep their MQTT
            # triggers, which ignore the empty action sent after each press.
            legacy_action_sensor = true;
          };
          availability = true;
          advanced = {
            transmit_power = 20;
            # At "info" every MQTT publish is logged (~1200 lines an hour),
            # and the journal's size cap kept only the last few hours, so
            # coordinator stalls (SRSP timeouts) and failed commands could not
            # be counted over days. Errors and warnings still get through.
            log_level = "warning";
          };
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

        # Both libraries' syrupy snapshot tests fail against the nixpkgs
        # 09063bd package set; the code itself is fine. Drop once upstream
        # refreshes the snapshots.
        package = pkgs.home-assistant.override {
          packageOverrides = _: super: {
            tailscale = super.tailscale.overridePythonAttrs { doCheck = false; };
            python-roborock = super.python-roborock.overridePythonAttrs { doCheck = false; };
          };
        };

        # The three entries marked "discovered on the LAN" are not used
        # directly: zeroconf/bluetooth discovery kept trying to open a config
        # flow for them and failing with `No module named ...` on every start
        # (homekit_controller alone was ~30 tracebacks per boot). Building them
        # in is what makes the discovery flow work instead of erroring.
        #
        # aioipp and broadlink-async: the ipp and broadlink integrations'
        # requirements since HA 2026.10, missing from nixpkgs (see ./aioipp.nix,
        # ./broadlink_async.nix).
        extraPackages = ps: [
          (ps.callPackage ./aioipp.nix { })
          (ps.callPackage ./broadlink_async.nix { })
        ];
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
          # Model Context Protocol server at /api/mcp, for Claude Code (.mcp.json).
          # It serves the Assist API: only entities exposed to Assist are visible.
          "mcp_server"
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
          # Divoom Timebox-Evo display over Bluetooth Classic (RFCOMM, which
          # nixpkgs' python already supports). Config-flow setup; the speaker
          # must be paired and trusted with bluetoothctl on the host first.
          (pkgs.buildHomeAssistantComponent rec {
            owner = "d03n3rfr1tz3";
            domain = "divoom";
            version = "1.5.1";
            src = pkgs.fetchFromGitHub {
              inherit owner;
              repo = "hass-divoom";
              rev = "v${version}";
              hash = "sha256-Gt8OQtEi2bidALCz6sQ8Z0Tcc7Aqww3sa1PSbUoR1JU=";
            };
            dontConfigure = true;
            dontBuild = true;
            doCheck = false;
            propagatedBuildInputs = [
              hassPythonPkgs.pillow
              hassPythonPkgs.zstandard
            ];
          })
          (pkgs.buildHomeAssistantComponent {
            owner = "JurajNyiri";
            domain = "tapo_control";
            # Keep in sync with the tag `inputs.hass-tapo-control` is pinned to
            # in flake.nix (and with the version in its manifest.json).
            version = "7.1.27";
            src = inputs.hass-tapo-control;
            # manifest.json pins `python-kasa==0.10.2`, nixpkgs ships 0.11. No
            # module of 7.1.27 imports kasa; upstream relaxed the pin to
            # `>=0.10.2` in 7.2.8. Drop this when bumping past it.
            ignoreVersionRequirement = [ "python-kasa" ];
            dontConfigure = true;
            dontBuild = true;
            doCheck = false;

            # `pytapo` here is the let-bound 3.4.19 override, not
            # hassPythonPkgs.pytapo — see the comment on it above.
            propagatedBuildInputs = [
              pytapo
              hassPythonPkgs.aiohttp
              hassPythonPkgs.requests
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
          # Chores from the donetick instance as todo/calendar/sensor entities.
          # Config-flow setup: donetick URL + a per-user API token. No manifest
          # requirements beyond core HA deps.
          (pkgs.buildHomeAssistantComponent {
            owner = "donetick";
            domain = "donetick";
            # manifest.json's version; the source itself is pinned to a commit
            # in flake.nix (upstream has no tags).
            version = "2.0.1";
            src = inputs.donetick-hass;
            dontConfigure = true;
            dontBuild = true;
            doCheck = false;
          })
          # Bubble Card's backend: keeps its modules as YAML files under
          # /config/bubble_card/modules (see the tmpfiles rules below). Replaced
          # the `Bubble Card Modules` template sensor. Its automatic migration
          # did not run here (the Origami files were already in place), so
          # daf_module and square_light_card were written over its websocket
          # API by hand on 2026-10-15.
          # Config-flow setup, no requirements.
          (pkgs.buildHomeAssistantComponent rec {
            owner = "Clooos";
            domain = "bubble_card_tools";
            version = "1.1.1";
            src = pkgs.fetchFromGitHub {
              inherit owner;
              repo = "Bubble-Card-Tools";
              rev = "v${version}";
              hash = "sha256-It74yOhvPaLE81eb6JGir4NWRe+wIi1woapx6EoOEf0=";
            };
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
          custom-brand-icons
          decluttering-card
          fold-entity-row
          hourly-weather
          light-entity-card
          mini-graph-card
          mini-media-player
          multiple-entity-row
          mushroom
          navbar-card
          pkgs.dafos.lovelace-auto-entities
          pkgs.dafos.lovelace-idf-mobilite
          pkgs.dafos.lovelace-layout-card
          pkgs.dafos.lovelace-origami
          pkgs.dafos.lovelace-origami-notifications
          pkgs.dafos.lovelace-origami-weather
          pkgs.dafos.lovelace-paper-buttons-row
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

          # Origami (github.com/hazymorning/origami), the theme of the Maison
          # dashboard. Selected per user in the profile.
          frontend.themes = "!include_dir_merge_named ${pkgs.dafos.lovelace-origami.themes}";

          # The go2rtc server below, for WebRTC camera streams.
          go2rtc.url = "http://127.0.0.1:1984";

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

          inherit (printerInk) command_line;

          "automation manual" =
            airQuality.automations
            ++ statusNotices.automations
            ++ printerInk.automations
            ++ appliancePrograms.automations
            ++ vacuumProgress.automations
            ++ heatingUsage.automations
            ++ netatmoWatchdog.automations
            ++ pellets.automations
            ++ deskCube.automations
            ++ bilresa.automations
            ++ rodret.automations
            ++ heatingController.automations
            ++ trvExternalSensors.automations
            ++ co2.automations
            ++ divoom.automations;
          "automation ui" = "!include automations.yaml";
          "scene ui" = "!include scenes.yaml";
          "script ui" = "!include_dir_merge_named scripts/";
          "script origami" = origami.scripts;
          "script tv" = tv.scripts;

          "template" = [
            # Template binary sensors + sensors migrated from the legacy
            # `binary_sensor:`/`sensor: - platform: template` format that HA
            # 2026.6 removed. They now live under the modern `template:`
            # integration as separate blocks.
            { binary_sensor = import ./sensors/binary_sensors.nix; }
            { sensor = import ./sensors/template_sensors.nix; }
            # The Maison dashboard (Origami), see ./origami/rooms.nix.
            { sensor = origami.sensors ++ offline.sensors; }
            { binary_sensor = lightTriggers.binarySensors; }
            {
              binary_sensor = airQuality.binarySensors;
              sensor = airQuality.sensors;
            }
          ]
          ++ heatingUsage.templates
          ++ pellets.templates;

          input_boolean =
            import ./sensors/input_booleans.nix // origami.input_boolean // airQuality.input_boolean;
          input_datetime =
            import ./sensors/input_datetimes.nix // netatmoWatchdog.input_datetime // pellets.input_datetime;
          inherit (pellets) input_button;
          input_number = import ./sensors/input_numbers.nix // pellets.input_number;
          input_text = import ./sensors/input_texts.nix // appliancePrograms.input_text;
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
          ++ (import ./sensors/sensors.nix)
          ++ origami.platformSensors
          ++ heatingUsage.platformSensors
          ++ pellets.platformSensors;

          # No `zha:` block: ZHA is config-flow only. It reads the coordinator
          # from the config entry and `create_zha_config` overwrites whatever
          # YAML put in zigpy_config.device, so setting it here did nothing.
          # The local SONOFF dongle is ZHA's; zigbee2mqtt drives the separate
          # network on the remote zstack coordinator (serialPortZigbee2Mqtt).
        };
      };
    };

    # Kept open to the LAN on purpose, unlike immich: with internal_url unset,
    # HA hands Cast speakers and ESPHome voice satellites media URLs on
    # http://<lan ip>:8123 (TTS, announcements), and they fetch them directly.
    # Closing it needs internal_url pointed at the Traefik host and a TTS test
    # first.
    networking.firewall = {
      allowedTCPPorts = [
        8123
        # go2rtc WebRTC media (below)
        8555
      ];
      allowedUDPPorts = [ 8555 ];
    };

    # go2rtc for camera streams. Without it HA's go2rtc integration has no
    # server and cameras only offer HLS, which takes 5-10 s to show the first
    # frame; with it the frontend gets WebRTC. HA registers each camera's
    # source (credentials included) through the API at runtime, so nothing
    # secret lives here. API and RTSP stay on loopback: go2rtc has no auth.
    services.go2rtc = {
      enable = true;
      settings = {
        api.listen = "127.0.0.1:1984";
        rtsp.listen = "127.0.0.1:8554";
        webrtc.listen = ":8555";
      };
    };
    # go2rtc saves every stream HA adds into its first config file and answers
    # 400 when it cannot: the module's file is in the read-only store, so the
    # first WebRTC offer after each go2rtc start failed. /dev/null as the first
    # file takes the write and keeps nothing, so the camera credentials HA
    # sends are never written to disk; the real settings follow it.
    systemd.services.go2rtc.serviceConfig.ExecStart = mkForce (
      lib.escapeShellArgs [
        (lib.getExe' config.services.go2rtc.package "go2rtc")
        "-config"
        "/dev/null"
        "-config"
        ((pkgs.formats.yaml { }).generate "go2rtc.yaml" config.services.go2rtc.settings)
      ]
    );

    # HA's failed logins, copied to a plain file for CrowdSec (the
    # crowdsecurity/home-assistant collection, wired in the crowdsec HM
    # module). HA logs only to the journal, and the rootless crowdsec
    # container can neither read the system journal nor ship journalctl.
    # Behind Traefik, HA logs the real client address (use_x_forwarded_for),
    # so CrowdSec bans the attacker, not the proxy.
    #
    # Root without capabilities: the journal files are root-owned, and a
    # DynamicUser would put the log under /var/log/private (0700), out of the
    # container's reach.
    #
    # The directory comes from an activation script, not LogsDirectory or
    # tmpfiles: systemd opens `append:` before it creates LogsDirectory (the
    # unit died with 209/STDOUT), and the crowdsec quadlet, restarted by
    # home-manager earlier in the same switch, mkdirs any missing volume
    # source as daf and failed on /var/log. Activation runs before either.
    system.activationScripts.hass-auth-log = ''
      install -d -m 0755 /var/log/hass-auth
      touch /var/log/hass-auth/hass.log
      chmod 0644 /var/log/hass-auth/hass.log
    '';
    systemd.services.hass-auth-log = {
      description = "Copy Home Assistant failed logins to a file for CrowdSec";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = lib.escapeShellArgs [
          "${config.systemd.package}/bin/journalctl"
          "--follow"
          "--lines=0"
          "--output=cat"
          "--unit=home-assistant.service"
          "--grep=Login attempt or request with invalid authentication"
        ];
        StandardOutput = "append:/var/log/hass-auth/hass.log";
        UMask = "0022";
        Restart = "always";
        RestartSec = 5;
        CapabilityBoundingSet = "";
        NoNewPrivileges = true;
        PrivateNetwork = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [ "AF_UNIX" ];
        SystemCallFilter = [ "@system-service" ];
      };
    };
    services.logrotate.settings."/var/log/hass-auth/hass.log" = {
      frequency = "weekly";
      rotate = 4;
      # journalctl keeps the file open; CrowdSec's file source follows truncation.
      copytruncate = true;
      missingok = true;
      notifempty = true;
    };

    # NOTE: the mode on /var/lib/hass itself is not actually 0775 — it is the
    # hass user's home and `createHome` re-chmods it to 0700 on every
    # activation, after tmpfiles has run. Combined with the unit's UMask=0077
    # that also makes `dafos.user.extraGroups = [ "hass" ]` above a no-op. To
    # genuinely give daf read access it would take
    # `users.users.hass.homeMode = "750"` plus a UMask override, which is a
    # deliberate weakening of upstream's hardening — left alone for now. The
    # two subdirectories are still worth creating; HA needs them to exist.
    #
    # Origami's Bubble Card modules are copied, not symlinked: Bubble Card
    # Tools resolve()s every module path and rejects one that lands outside
    # /config/bubble_card. `C+` re-copies them on each activation, so the pinned
    # version wins over edits made in the module editor; modules of our own sit
    # beside them under other names and stay editable.
    systemd.tmpfiles.rules = [
      "d /var/lib/hass/scripts 0775 hass hass -"
      "d /var/lib/hass/custom_templates 0775 hass hass -"
      "d /var/lib/hass/bubble_card 0755 hass hass -"
      "d /var/lib/hass/bubble_card/modules 0755 hass hass -"
    ]
    ++
      map
        (
          name:
          "C+ /var/lib/hass/bubble_card/modules/origami_${name}.yaml - - - - ${pkgs.dafos.lovelace-origami.bubbleCardModules}/origami_${name}.yaml"
        )
        # Listed by hand: readDir on the fetched source would be IFD.
        [
          "base"
          "button"
          "climate"
          "fan"
          "header"
          "light"
          "media"
          "popup"
          "slider"
          "speaker"
          "tiles"
        ]
    # lsismeiro's light hook, patched for HA 2026.10's colour temperature in
    # kelvins (see the file's header). Linked over the UI-imported copy, so a
    # re-import from the UI cannot bring the broken version back.
    ++ [
      "L+ /var/lib/hass/blueprints/automation/lsismeiro/light.yaml - - - - ${./blueprints/lsismeiro/light.yaml}"
    ]
    ++ divoom.tmpfiles;
  };
}
