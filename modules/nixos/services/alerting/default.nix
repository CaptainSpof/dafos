{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkIf
    types
    optionals
    optionalString
    genAttrs
    getExe
    ;
  inherit (lib.${namespace}) mkOpt mkBoolOpt;

  cfg = config.${namespace}.services.alerting;
  host = config.networking.hostName;

  alert = pkgs.writeShellApplication {
    name = "dafos-alert";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      title=''${1:?usage: dafos-alert TITLE [MESSAGE]}
      message=''${2:-}
      jq -n --arg title "$title" --arg message "$message" '{title: $title, message: $message}' |
        curl -fsS --max-time 10 -X POST -H 'Content-Type: application/json' --data @- \
          "${cfg.homeAssistantUrl}/api/webhook/${cfg.webhookId}"
    '';
  };

  unitFailureAlert =
    user:
    pkgs.writeShellScript "alert-unit-failure" ''
      unit="$1"
      logs=$(${pkgs.systemd}/bin/journalctl ${optionalString user "--user"} -u "$unit" -n 5 -o cat --no-pager || true)
      exec ${getExe alert} "${host} : $unit en échec" "$logs"
    '';

  failureTemplate = user: {
    description = "Alert Home Assistant that %i failed";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${unitFailureAlert user} %i";
    };
  };

  smartdAlert = pkgs.writeShellScript "smartd-alert" ''
    exec ${getExe alert} "${host} : disque $SMARTD_DEVICESTRING" "$SMARTD_MESSAGE"
  '';
in
{
  options.${namespace}.services.alerting = {
    enable = mkEnableOption "server alerts relayed to phones through Home Assistant";

    homeAssistantUrl =
      mkOpt types.str "http://127.0.0.1:8123"
        "Home Assistant instance that relays the alerts.";

    # Not a secret: the automation below is `local_only`, so Home Assistant
    # refuses it from anything but the LAN and tailnet. It only has to be
    # unguessable enough that a stray LAN device cannot spam the phones.
    webhookId =
      mkOpt types.str "dafoltop-alert-769827bc5d06e383701ca8df"
        "Home Assistant webhook the alerts are posted to. Read by the home-manager side too.";

    notify = mkOpt (types.listOf types.str) [
      "notify.mobile_app_dafphone"
    ] "Home Assistant notify actions that receive each alert.";

    units = mkOpt (types.listOf types.str) (
      optionals config.services.home-assistant.enable [ "home-assistant" ]
      ++ optionals config.services.zigbee2mqtt.enable [ "zigbee2mqtt" ]
      ++ optionals config.services.mosquitto.enable [ "mosquitto" ]
      ++ optionals config.services.immich.enable [
        "immich-server"
        "immich-machine-learning"
      ]
      ++ optionals config.services.postgresql.enable [ "postgresql" ]
      ++ optionals config.services.blocky.enable [ "blocky" ]
    ) "System units that raise an alert when they end up failed.";

    smartd.enable = mkBoolOpt true "Whether to watch every disk with smartd and alert on SMART problems.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ alert ];

    # `dafos-alert TITLE MESSAGE` posts here; the automation fans the alert out
    # to the phones and leaves a persistent notification in the HA UI. When HA
    # itself is down nothing is relayed, so HA failures only show up once it
    # is back (as a persistent notification) or through gatus.
    services.home-assistant.config."automation manual" = mkIf config.services.home-assistant.enable [
      {
        id = "dafos_server_alert";
        alias = "Alerte serveur";
        description = "Relays alerts posted by dafos-alert (smartd, failed units, gatus).";
        mode = "queued";
        triggers = [
          {
            trigger = "webhook";
            webhook_id = cfg.webhookId;
            allowed_methods = [ "POST" ];
            local_only = true;
          }
        ];
        actions =
          let
            data = {
              title = "{{ trigger.json.title }}";
              message = "{{ trigger.json.message }}";
            };
          in
          [
            {
              action = "persistent_notification.create";
              inherit data;
            }
          ]
          ++ map (action: { inherit action data; }) cfg.notify;
      }
    ];

    # OnFailure only fires once a unit is marked failed, so a service that
    # restarts itself only alerts after it exhausts its start limit.
    systemd.services =
      genAttrs cfg.units (_: {
        onFailure = [ "alert-failure@%n.service" ];
      })
      // {
        "alert-failure@" = failureTemplate false;
      };
    # For the rootless podman stacks: their quadlets point OnFailure here.
    systemd.user.services."alert-failure@" = failureTemplate true;

    services.smartd = mkIf cfg.smartd.enable {
      enable = true;
      # `-n standby,q` skips a sleeping disk instead of spinning it up every
      # poll. The notify options go here rather than through
      # services.smartd.notifications, which only knows mail/wall/x11.
      defaults.autodetected = "-a -n standby,q -m <nomailer> -M exec ${smartdAlert}";
    };
  };
}
