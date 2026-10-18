# dafspi (Roborock) cycle as a sticky Android Live Update on dafphone, for
# every cycle however it started (Global · dafspi Auto Clean, the Maison
# dashboard, the Roborock app): the room being cleaned, the progress the
# robot reports (sensor.dafspi_cleaning_progress), area and time so far.
#
# Its button sends GLOBAL_VACUUM_STOP, which Global · dafspi Auto Clean (UI)
# already handles: it clears the notification and sends dafspi to its dock.
# This automation then shows the way home until the dock, and clears it there.
_:

let
  vacuum = "vacuum.dafspi";
  progress = "sensor.dafspi_cleaning_progress";
  room = "sensor.dafspi_current_room";
  area = "sensor.dafspi_cleaning_area";
  seconds = "sensor.dafspi_cleaning_time";
  battery = "sensor.dafspi_battery";
  error = "sensor.dafspi_vacuum_error";

  tag = "dafspi";
  notify = data: {
    action = "notify.mobile_app_dafphone";
    inherit data;
  };
  common = {
    inherit tag;
    group = "Maison";
    channel = "household";
  };
  # Live Update: shown in the status bar chip and on the lock screen, updated
  # in place without a new alert.
  live = common // {
    live_update = true;
    alert_once = true;
    sticky = true;
  };
  stop = {
    action = "GLOBAL_VACUUM_STOP";
    title = "Retour à la station";
  };
  done = notify {
    message = "clear_notification";
    data.tag = tag;
  };

  # "Couloir · 7.8 m² · 8 min · batterie 94 %"
  summary = ''
    {% set r = states('${room}') %}
    {{ (r ~ ' · ') if r not in ['unknown', 'unavailable', '''] else ''' -}}
    {{ states('${area}') | float(0) | round(1) }} m² · {{ (states('${seconds}') | int(0) / 60) | round(0) | int }} min · batterie {{ states('${battery}') | int(0) }} %
  '';
  percent = "{{ states('${progress}') | int(0) }}";

  isState = s: {
    condition = "state";
    entity_id = vacuum;
    state = s;
  };
in
{
  automations = [
    {
      id = "dafos_household_vacuum_progress";
      alias = "Household · Vacuum Progress";
      description = "dafspi's cycle as a sticky Live Update on dafphone (room, progress, area, time) with a button that sends it back to its dock; cleared once docked. Managed in Nix (modules/nixos/services/home-assistant/vacuum_progress.nix).";
      mode = "queued";
      max = 10;
      triggers = [
        {
          trigger = "state";
          entity_id = vacuum;
          not_to = [ "unavailable" ];
        }
        {
          trigger = "state";
          entity_id = [
            progress
            room
          ];
        }
        {
          trigger = "homeassistant";
          event = "start";
        }
      ];
      actions = [
        {
          choose = [
            {
              alias = "Cleaning or paused: progress, with the way home";
              conditions = [
                (isState [
                  "cleaning"
                  "paused"
                ])
              ];
              sequence = [
                (notify {
                  title = "{{ 'dafspi en pause' if is_state('${vacuum}', 'paused') else 'dafspi nettoie' }}";
                  message = summary;
                  data = live // {
                    notification_icon = "mdi:robot-vacuum";
                    progress = percent;
                    progress_max = 100;
                    critical_text = "${percent} %";
                    actions = [ stop ];
                  };
                })
              ];
            }
            {
              alias = "On the way home";
              conditions = [ (isState "returning") ];
              sequence = [
                (notify {
                  title = "dafspi rentre à la station";
                  message = summary;
                  data = live // {
                    notification_icon = "mdi:home-import-outline";
                    critical_text = "Retour";
                  };
                })
              ];
            }
            {
              alias = "Stuck: say why, without the live update";
              conditions = [ (isState "error") ];
              sequence = [
                (notify {
                  title = "dafspi est bloqué";
                  message = "{{ states('${error}') }} · {{ states('${room}') }}";
                  data = common // {
                    notification_icon = "mdi:robot-vacuum-alert";
                    importance = "high";
                    actions = [ stop ];
                  };
                })
              ];
            }
            {
              alias = "Docked or idle: nothing to follow any more";
              conditions = [
                (isState [
                  "docked"
                  "idle"
                ])
                {
                  alias = "Only on dafspi's own change or a restart, not on every sensor update";
                  condition = "template";
                  value_template = "{{ trigger.platform != 'state' or trigger.entity_id == '${vacuum}' }}";
                }
              ];
              sequence = [ done ];
            }
          ];
        }
      ];
    }
  ];
}
