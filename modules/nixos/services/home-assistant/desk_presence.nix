# Somebody at the desk upstairs, and the ground floor left empty: the heating
# controller (./heating_controller.nix) then keeps the ground-floor rooms on
# eco and stops starting the stove.
#
# binary_sensor.desk_dafbox_in_use: dafbox pushes {"active": bool} to a webhook
# every minute and on every change (flake-modules/services/desk-presence.nix):
# active = session unlocked and input in the last 5 min, an idle inhibitor
# (video, most games) counting as input. Off on lock, idle, suspend; with no
# push for 3 min (dafbox off or crashed) auto_off turns it off. The desk has no
# presence sensor, so this is the only proof somebody sits there. The webhook
# id is a secret (secrets/dafoltop/dafbox-presence.yaml).
#
# binary_sensor.heating_ground_floor_idle: on once dafbox has been in use and
# the ground floor quiet (no motion, no activity) for 30 min together. Off as
# soon as somebody shows up downstairs for sure (a door, a switch: activity),
# on motion that looks like a person rather than the cat (on for 5 min
# straight, or 3 detections in 10 min), or when dafbox has been unused for
# 10 min. Streaming from dafbox to the living room TV keeps dafbox active, but
# the living room's mmWave sees the player, so the ground floor is not empty.
_:

let
  inUse = "binary_sensor.desk_dafbox_in_use";
  idle = "binary_sensor.heating_ground_floor_idle";
  motion = "binary_sensor.ground_floor_motion";
  activity = "binary_sensor.ground_floor_activity";
  motionCount = "sensor.heating_ground_floor_motion_count";
in
{
  # Motion detections downstairs over the last 10 min (sensor.heating_ground_floor_motion_count).
  platformSensors = [
    {
      platform = "history_stats";
      name = "Heating ground floor motion count";
      unique_id = "dafos.sensor.heating_ground_floor_motion_count";
      entity_id = motion;
      state = "on";
      type = "count";
      start = "{{ now() - timedelta(minutes=10) }}";
      end = "{{ now() }}";
    }
  ];

  # webhookId: path of the secret file. HA's `!include` parses it as YAML, and
  # a file holding the bare id is a YAML string.
  templates = webhookId: [
    {
      triggers = [
        {
          trigger = "webhook";
          webhook_id = "!include ${webhookId}";
          allowed_methods = [ "POST" ];
          # dafbox reaches home.daftdaf.dev over the tailnet (100.x), which
          # HA counts as remote; the secret id is the protection.
          local_only = false;
        }
      ];
      binary_sensor = [
        {
          name = "Desk · dafbox in use";
          unique_id = "dafos.binary_sensor.desk_dafbox_in_use";
          default_entity_id = inUse;
          device_class = "occupancy";
          icon = "mdi:monitor-account";
          state = "{{ trigger.json.active | default(false) | bool(false) }}";
          auto_off.minutes = 3;
        }
      ];
    }
    {
      triggers = [
        {
          trigger = "template";
          id = "empty";
          value_template = "{{ is_state('${inUse}', 'on') and is_state('${motion}', 'off') and is_state('${activity}', 'off') }}";
          for.minutes = 30;
        }
        {
          trigger = "state";
          id = "back";
          entity_id = activity;
          to = "on";
        }
        {
          trigger = "state";
          id = "back";
          entity_id = motion;
          to = "on";
          for.minutes = 5;
        }
        {
          trigger = "numeric_state";
          id = "back";
          entity_id = motionCount;
          above = 2;
        }
        {
          trigger = "state";
          id = "back";
          entity_id = inUse;
          to = "off";
          for.minutes = 10;
        }
      ];
      binary_sensor = [
        {
          name = "Heating · Ground floor idle";
          unique_id = "dafos.binary_sensor.heating_ground_floor_idle";
          default_entity_id = idle;
          icon = "mdi:home-floor-0";
          state = "{{ trigger.id == 'empty' }}";
        }
      ];
    }
  ];
}
