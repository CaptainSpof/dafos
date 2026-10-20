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

  platformSensors = concatMap stats heaters ++ [
    # The stove's power, highest over the last 10 min: maybe_burning (UI
    # template) and the heating controller read it, since a burning stove
    # oscillates between 18 and 140 W. It was a UI statistics helper tied to
    # the plug's ZHA device, and went with it when the plug moved to
    # Zigbee2MQTT (2026-10-20); here it no longer depends on any device.
    {
      platform = "statistics";
      name = "Living Room · Stove Power Max 10 min";
      unique_id = "dafos.sensor.living_room_stove_power_max_10_min";
      entity_id = "sensor.living_room_stove_power";
      state_characteristic = "value_max";
      max_age.minutes = 10;
      sampling_size = 1000;
      # The plug only reports on change: keep the last reading as a sample so
      # a steady draw does not age out to "unknown".
      keep_last_sample = true;
    }
  ];

  # A phone notification when the stove lights or the boiler starts heating,
  # replaced in silence by the run's length when it stops (same tag).
  automations = [
    {
      id = "dafos_heating_usage_notifications";
      alias = "Heating · Usage Notifications";
      description = "Notifies dafphone when the stove lights or the boiler starts heating, and replaces it with the run's length when it stops. Managed in Nix (modules/nixos/services/home-assistant/heating_usage.nix).";
      mode = "queued";
      triggers = concatMap (h: [
        {
          trigger = "state";
          entity_id = h.on;
          from = "off";
          to = "on";
          id = "${h.id}-on";
        }
        {
          trigger = "state";
          entity_id = h.on;
          from = "on";
          to = "off";
          id = "${h.id}-off";
        }
      ]) heaters;
      actions = [
        {
          choose = concatMap (h: [
            {
              conditions = [
                {
                  condition = "trigger";
                  id = "${h.id}-on";
                }
              ];
              sequence = [
                {
                  action = "notify.mobile_app_dafphone";
                  data = {
                    title = "${h.name} en marche";
                    message = "Démarré à {{ now().strftime('%H:%M') }} · salon à {{ states('sensor.living_room_current_temperature') }} °C";
                    data = {
                      tag = "heating_${h.id}";
                      group = "Chauffage";
                      channel = "Chauffage";
                      notification_icon = h.icon;
                    };
                  };
                }
              ];
            }
            {
              conditions = [
                {
                  condition = "trigger";
                  id = "${h.id}-off";
                }
              ];
              sequence = [
                {
                  action = "notify.mobile_app_dafphone";
                  data = {
                    title = "${h.name} arrêté";
                    message = "Après {{ ((now() - trigger.from_state.last_changed).total_seconds() / 60) | round(0) | int }} min, à {{ now().strftime('%H:%M') }} · salon à {{ states('sensor.living_room_current_temperature') }} °C";
                    data = {
                      tag = "heating_${h.id}";
                      group = "Chauffage";
                      channel = "Chauffage";
                      notification_icon = h.icon;
                      # Updates the start notification without a new alert
                      alert_once = true;
                    };
                  };
                }
              ];
            }
          ]) heaters;
        }
      ];
    }
  ];

  inherit heaters;
}
