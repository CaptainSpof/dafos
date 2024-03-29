{ config, lib, pkgs, ... }:

with lib;
with lib.dafos;
let
  cfg = config.dafos.services.home-assistant;
  vars = config.dafos.vars;
  pyforked-daapd = pkgs.python3Packages.buildPythonPackage rec {
    pname = "pyforked-daapd";
    version = "v0.1.14";
    propagatedBuildInputs = [ pkgs.python3Packages.aiohttp ];

    src = pkgs.fetchFromGitHub {
      owner = "uvjustin";
      repo = "${pname}";
      rev = "21d901d4ececdfa9391a12f9be70c8d2e7bcd424";
      sha256 = "sha256-dPDhBe/CEslgEomt5HgAf4nbW0izXM5fSNRe96ULYlg=";
    };
  };
in
{
  imports = [ ../../../vars.nix ];
  options.dafos.services.home-assistant = with types; {
    enable = mkBoolOpt false "Whether or not to enable home-assistant.";
    serialPort = mkOpt str "/dev/ttyACM0" "The serial port to use.";
  };

  config = mkIf cfg.enable {

    dafos.user.extraGroups = [ "hass" ];

    environment.systemPackages = with pkgs; [
      ffmpeg_5
    ];

    services.mosquitto = {
      enable = true;
      listeners = [{
        acl = [ "pattern readwrite #" ];
        omitPasswordAuth = true;
        settings.allow_anonymous = true;
      }];
    };

    services.zigbee2mqtt = {
      enable = true;
      settings = {
        homeassistant = config.services.home-assistant.enable;
        permit_join = true;
        mqtt = {
          server = "mqtt://127.0.0.1:1883";
          base_topic = "zigbee2mqtt";
        };
        frontend = {
          port = 8090;
        };
        serial = {
          port = "/dev/ttyACM1";
          adapter = "deconz";
        };
        advanced = { log_level = "debug"; };
      };
    };

    services.home-assistant = {
      enable = true;
      extraComponents = [
	      "radarr"
	      "sonarr"
        "apple_tv"
        "backup"
        "cast"
        "esphome"
        "forked_daapd"
        "freebox"
        "google_translate"
        "ipp"
        "local_calendar"
        "ld2410_ble"
        "met"
        "mobile_app"
        "mqtt"
        "netatmo"
        "radio_browser"
        "roborock"
        "samsungtv"
        "tailscale"
        "telegram"
        "tuya"
        "wled"
        "yeelight"
        "zeroconf"
        "zha"
      ];

      extraPackages = ps: with ps; [
        pychromecast
        pyforked-daapd
      ];

      customComponents = with pkgs.home-assistant-custom-components; [
        adaptive_lighting
      ];

      customLovelaceModules = with pkgs.home-assistant-custom-lovelace-modules; [
        mini-graph-card
        mini-media-player
        mushroom
        pkgs.dafos.lovelace-layout-card
        pkgs.dafos.lovelace-fold-entity-row
        pkgs.dafos.lovelace-auto-entities
        pkgs.dafos.button-card
      ];

      config = {
        # Includes dependencies for a basic setup
        # https://www.home-assistant.io/integrations/default_config/
        default_config = { };
        lovelace.mode = "yaml";
        lovelace.resources = [
          {
            url = "/local/nixos-lovelace-modules/mushroom.js";
            type = "module";
          }
          {
            url = "/local/nixos-lovelace-modules/layout-card.js";
            type = "module";
          }
          {
            url = "/local/nixos-lovelace-modules/button-card.js";
            type = "module";
          }
          {
            url = "/local/nixos-lovelace-modules/fold-entity-row.js";
            type = "module";
          }
          {
            url = "/local/nixos-lovelace-modules/auto-entities.js";
            type = "module";
          }
          {
            url = "/local/nixos-lovelace-modules/mini-graph-card-bundle.js";
            type = "module";
          }
          {
            url = "/local/nixos-lovelace-modules/mini-media-player-bundle.js";
            type = "module";
          }
        ];

        "automation manual" = [ ];
        "automation ui" = "!include automations.yaml";
        "scene ui" = "!include scenes.yaml";
        "script ui" = "!include scripts.yaml";

        sensor = {
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
        };
      };
    };

    virtualisation.oci-containers = {
      backend = "podman";
      containers.ha-fusion = {
        volumes = [
          "/var/lib/hass:/app/data"
        ];
        ports = [ "5050:5050" ];
        environment.TZ = vars.timezone;
        environment.HASS_URL = "http://dafoltop:8123";
        image = "ghcr.io/matt8707/ha-fusion";
        extraOptions = [
          "--network=host"
        ];
      };
    };

    networking.firewall = {
      allowedTCPPorts = [ 80 443 8123 ];
    };
  };
}
