# How the house is heated, stove against boiler: one on/off signal for each,
# their latest run, and daily and weekly totals, for the Maison dashboard's
# "Usage du chauffage" pop-up (opened from the heating pop-up).
#
# Stove: binary_sensor.living_room_stove_is_maybe_burning alone also counts
# the plug's switch-on spike (~50-66 W held 10 min by the max-10-min sensor)
# as 10-13 min runs. A real fire always starts with the igniter (320-390 W for
# about 8 min), so a run starts there and ends when maybe_burning goes off.
#
# Boiler: there is no boiler sensor; the Netatmo thermostat (climate.sejour)
# drives the boiler relay and reports it as hvac_action "heating". Netatmo
# polls every ~10 min, so its runs are known to that precision.
{ lib }:

let
  inherit (lib) concatMap;

  stoveMax = "sensor.living_room_stove_power_max_10_min";
  stoveMaybe = "binary_sensor.living_room_stove_is_maybe_burning";
  ignition = 250; # W, only the igniter draws this much

  heaters = [
    {
      id = "stove";
      name = "Poêle";
      on = "binary_sensor.heating_stove_burning";
      icon = "mdi:fireplace";
    }
    {
      id = "boiler";
      name = "Chaudière";
      on = "binary_sensor.heating_boiler_heating";
      icon = "mdi:water-boiler";
    }
  ];

  # Entity ids follow the names (history_stats has no default_entity_id):
  # sensor.heating_<id>_today, _week, _starts_today, _starts_week.
  stats = h: [
    {
      platform = "history_stats";
      name = "Heating ${h.id} today";
      unique_id = "dafos.sensor.heating_${h.id}_today";
      entity_id = h.on;
      state = "on";
      type = "time";
      start = "{{ today_at() }}";
      end = "{{ now() }}";
    }
    {
      platform = "history_stats";
      name = "Heating ${h.id} week";
      unique_id = "dafos.sensor.heating_${h.id}_week";
      entity_id = h.on;
      state = "on";
      type = "time";
      start = "{{ today_at() - timedelta(days=6) }}";
      end = "{{ now() }}";
    }
    {
      platform = "history_stats";
      name = "Heating ${h.id} starts today";
      unique_id = "dafos.sensor.heating_${h.id}_starts_today";
      entity_id = h.on;
      state = "on";
      type = "count";
      start = "{{ today_at() }}";
      end = "{{ now() }}";
    }
    {
      platform = "history_stats";
      name = "Heating ${h.id} starts week";
      unique_id = "dafos.sensor.heating_${h.id}_starts_week";
      entity_id = h.on;
      state = "on";
      type = "count";
      start = "{{ today_at() - timedelta(days=6) }}";
      end = "{{ now() }}";
    }
  ];

  # Trigger-based, so they keep their value across restarts: the start and the
  # length of the latest run, updated as each run starts and ends.
  lastRun = h: {
    triggers = [
      {
        trigger = "state";
        entity_id = h.on;
        from = "off";
        to = "on";
        id = "start";
      }
      {
        trigger = "state";
        entity_id = h.on;
        from = "on";
        to = "off";
        id = "end";
      }
    ];
    sensor = [
      {
        name = "${h.name} · Dernier démarrage";
        unique_id = "dafos.sensor.heating_${h.id}_last_start";
        default_entity_id = "sensor.heating_${h.id}_last_start";
        device_class = "timestamp";
        inherit (h) icon;
        state = "{{ trigger.to_state.last_changed if trigger.id == 'start' else (this.state if has_value(this.entity_id) else none) }}";
      }
      {
        name = "${h.name} · Durée du dernier cycle";
        unique_id = "dafos.sensor.heating_${h.id}_last_duration";
        default_entity_id = "sensor.heating_${h.id}_last_duration";
        device_class = "duration";
        unit_of_measurement = "min";
        icon = "mdi:timer-outline";
        state = ''
          {{ ((now() - trigger.from_state.last_changed).total_seconds() / 60) | round(0) | int
             if trigger.id == 'end' else (this.state if has_value(this.entity_id) else none) }}
        '';
      }
    ];
  };
in
{
  templates = [
    {
      binary_sensor = [
        {
          name = "Chaudière · En chauffe";
          unique_id = "dafos.binary_sensor.heating_boiler_heating";
          default_entity_id = "binary_sensor.heating_boiler_heating";
          device_class = "heat";
          icon = "mdi:water-boiler";
          state = "{{ state_attr('climate.sejour', 'hvac_action') == 'heating' }}";
          availability = "{{ has_value('climate.sejour') }}";
        }
      ];
    }
    {
      triggers = [
        {
          trigger = "numeric_state";
          entity_id = stoveMax;
          above = ignition;
          id = "lit";
        }
        {
          trigger = "state";
          entity_id = stoveMaybe;
          to = "off";
          id = "out";
        }
      ];
      binary_sensor = [
        {
          name = "Poêle · Allumé";
          unique_id = "dafos.binary_sensor.heating_stove_burning";
          default_entity_id = "binary_sensor.heating_stove_burning";
          device_class = "heat";
          icon = "mdi:fireplace";
          state = "{{ trigger.id == 'lit' }}";
        }
      ];
    }
  ]
  ++ map lastRun heaters;

  platformSensors = concatMap stats heaters;

  inherit heaters;
}
