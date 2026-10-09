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
# Appliance cycle detectors, consumed by the "Household · Appliances"
# automation. delay_off has to outlast the longest low-power pause inside a
# cycle (measured over two weeks of history: washer 8 min above 5 W, dryer 2 min
# above 25 W, dishwasher 10 min above 2 W during its drying phase), otherwise a
# pause reads as the end of the cycle.
#
# Being entities rather than `wait_for_trigger` steps, they survive HA restarts
# and automation reloads, which used to silently swallow end-of-cycle
# notifications. `availability` keeps a Zigbee dropout from reading as 0 W.
++ (map
  (a: {
    inherit (a) name;
    unique_id = "dafos.binary_sensor.${a.id}_active";
    default_entity_id = "binary_sensor.${a.id}_active";
    device_class = "running";
    state = "{{ states('${a.power}') | float(0) > ${toString a.threshold} }}";
    availability = "{{ has_value('${a.power}') }}";
    delay_on.minutes = 1;
    delay_off.minutes = a.delayOff;
  })
  [
    {
      id = "laundry_washing_machine";
      name = "Laundry · Washing Machine is active";
      power = "sensor.laundry_washing_machine_power";
      threshold = 5;
      delayOff = 10;
    }
    {
      id = "laundry_dryer";
      name = "Laundry · Dryer is active";
      power = "sensor.laundry_dryer_power";
      threshold = 25;
      delayOff = 5;
    }
    {
      id = "kitchen_dishwasher";
      name = "Kitchen · Dishwasher is active";
      power = "sensor.kitchen_dishwasher_plug_power";
      threshold = 2;
      delayOff = 15;
    }
  ]
)
