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
    # Count real people, never `zone.home`. This used to be
    # `{{ states('zone.home') | int > 0 }}`, which can never reach 0:
    # `person.kiosk` is the wall-mounted iPad and its GPS puts it permanently
    # inside zone.home's 100 m radius, so the zone counter floors at 1 and every
    # "nobody home" automation downstream silently stops firing. `person.daf`
    # has no trackers at all and sits at `unknown`.
    #
    # `House` is zone.house — radius ~14 m, entirely inside zone.home. A person
    # standing in it reports `House` instead of `home` because HA picks the
    # smallest matching zone, and that still means they are home.
    state = ''
      {{ states.person
         | rejectattr('entity_id', 'in', ['person.kiosk', 'person.daf'])
         | selectattr('state', 'in', ['home', 'House'])
         | list | count > 0 }}
    '';
    # Before the person entities load, `states.person` is empty and the state
    # template would render false — a spurious "nobody home" on every restart.
    availability = ''
      {{ states.person
         | rejectattr('entity_id', 'in', ['person.kiosk', 'person.daf'])
         | list | count > 0 }}
    '';
  }
  {
    name = "Véranda · daftv is running";
    unique_id = "dafos.binary_sensor.veranda_maybe_daftv_running";
    default_entity_id = "binary_sensor.veranda_maybe_daftv_running";
    device_class = "running";
    state = "{{ not(states('sensor.veranda_tv_plug_power') | float(0) < 30 and states('media_player.daftv') == 'off') }}";
  }
  {
    name = "Desk · dafbox is running";
    unique_id = "dafos.binary_sensor.desk_maybe_dafbox_running";
    default_entity_id = "binary_sensor.desk_maybe_dafbox_running";
    device_class = "running";
    state = "{{ not(states('sensor.desk_plug_power') | float(0) < 30 and states('device_tracker.dafbox') == 'not_home') }}";
  }
]
