# Template binary sensors in the modern `template:` integration format.
#
# HA 2026.6 removed the legacy `binary_sensor: - platform: template` format, so
# these are now consumed under `services.home-assistant.config.template` (see
# default.nix) as a `{ binary_sensor = [...]; }` block.
#
# `default_entity_id` pins the original entity_id (these never had a unique_id,
# so without it HA would slugify `name` and rename them, breaking automations).
[
  {
    name = "Global · Home is Occupied";
    unique_id = "dafos.binary_sensor.global_maybe_home_occupied";
    default_entity_id = "binary_sensor.global_maybe_home_occupied";
    device_class = "occupancy";
    state = ''{{ states('zone.home') | int > 0 }}'';
  }
  {
    name = "Véranda · daftv is running";
    unique_id = "dafos.binary_sensor.veranda_maybe_daftv_running";
    default_entity_id = "binary_sensor.veranda_maybe_daftv_running";
    device_class = "running";
    state = ''{{ not(states('sensor.veranda_tv_plug_power') | float < 25 and states('media_player.daftv') == 'off') }}'';
  }
  {
    name = "Desk · dafbox is running";
    unique_id = "dafos.binary_sensor.desk_maybe_dafbox_running";
    default_entity_id = "binary_sensor.desk_maybe_dafbox_running";
    device_class = "running";
    state = ''{{ not(states('sensor.desk_plug_power') | float < 25 and states('device_tracker.dafbox') == 'not_home') }}'';
  }
]
