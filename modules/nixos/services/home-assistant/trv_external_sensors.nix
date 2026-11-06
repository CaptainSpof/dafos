# Room thermometers fed to SONOFF TRVZB radiator valves as their external
# temperature, so a valve regulates on the room and not on its own sensor,
# which sits next to the radiator and reads several degrees warm.
#
# The valve's `temperature_sensor_select` goes to `remote_temperature`, and
# `external_temperature_input` gets the room reading on every change and every
# 10 min (the valve marks the remote source offline when it stops hearing
# from it). Should the thermometer go unavailable, the valve is put back on
# its own sensor.
_:

let
  valves = [
    {
      # Desk: the IKEA ALPSTUGA air quality monitor (Matter over Thread),
      # since 2026-10-22
      valve = "desk_radiator";
      sensor = "sensor.desk_air_quality_monitor_temperature";
    }
    {
      # Bedroom: the bedside Aqara (its valve read ~24 °C next to the radiator
      # while the room was cold), since 2026-10-23
      valve = "bedroom_radiator";
      sensor = "sensor.bedroom_bed_side_temperature_sensor_temperature";
    }
    {
      # Kitchen: the Aqara temperature sensor, since 2026-10-23
      valve = "kitchen_radiator";
      sensor = "sensor.kitchen_temperature_sensor_temperature_2";
    }
  ];

  automation =
    { valve, sensor }:
    let
      input = "number.${valve}_external_temperature_input";
      select = "select.${valve}_temperature_sensor_select";
    in
    {
      id = "dafos_trv_external_${valve}";
      alias = "Heating · ${valve} external sensor";
      description = "Envoie ${sensor} à la vanne ${valve} comme température externe, ou la remet sur son propre capteur quand ce thermomètre est indisponible. Géré dans Nix (modules/nixos/services/home-assistant/trv_external_sensors.nix).";
      mode = "queued";
      max = 3;
      triggers = [
        {
          trigger = "state";
          entity_id = sensor;
        }
        {
          trigger = "time_pattern";
          minutes = "/10";
        }
        {
          trigger = "homeassistant";
          event = "start";
        }
      ];
      actions = [
        {
          "if" = [
            {
              condition = "template";
              value_template = "{{ has_value('${sensor}') }}";
            }
          ];
          "then" = [
            {
              action = "number.set_value";
              target.entity_id = input;
              data.value = "{{ states('${sensor}') | float | round(1) }}";
            }
            {
              "if" = [
                {
                  condition = "not";
                  conditions = [
                    {
                      condition = "state";
                      entity_id = select;
                      state = "remote_temperature";
                    }
                  ];
                }
              ];
              "then" = [
                {
                  action = "select.select_option";
                  target.entity_id = select;
                  data.option = "remote_temperature";
                }
              ];
            }
          ];
          "else" = [
            {
              action = "select.select_option";
              target.entity_id = select;
              data.option = "local_temperature";
            }
          ];
        }
      ];
    };
in
{
  automations = map automation valves;
}
