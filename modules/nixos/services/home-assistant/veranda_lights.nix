# Veranda lights off once nobody has been around for a while, unless daftv is on.
#
# The veranda has no presence sensor of its own (its old Aqara P1 is gone): the
# living room's Everything Presence radar also covers it, and the dashboard
# already uses it as the veranda's presence. A press on the veranda's switch
# (RODRET), cube or button counts as someone there too.
#
# The delay is input_number.veranda_lights_off_delay (10 min by default). The
# lights go off once the radar, the switches and daftv have all been quiet for
# that long, and the lights have been on for that long. daftv counts as
# "on" through binary_sensor.veranda_maybe_daftv_running (plug drawing 30 W or
# more, or the media player not off); while it is, the lights stay on. When
# daftv goes off in an empty room, the countdown starts again from there.
#
# The TV lamp is left alone: "Véranda · daftv Controller" makes it follow
# the TV. The bulbs are turned off through their Zigbee2MQTT group, one
# broadcast instead of one command per bulb.
_:

let
  delayHelper = "input_number.veranda_lights_off_delay";
  lights = "light.veranda_all_lights";
  lightsGroup = "light.veranda_lights_group";
  radar = "binary_sensor.everything_presence_lite_61659c_occupancy";
  tv = "binary_sensor.veranda_maybe_daftv_running";
  activity = [
    "sensor.veranda_switch_action"
    "sensor.veranda_cube_action"
    "event.veranda_button_button_1"
    "event.veranda_button_button_2"
  ];

  delay.minutes = "{{ states('${delayHelper}') | int(10) }}";
  quietFor = entity: {
    trigger = "state";
    entity_id = entity;
    to = "off";
    "for" = delay;
  };
  quietSince = entity: {
    condition = "state";
    entity_id = entity;
    state = "off";
    "for" = delay;
  };
in
{
  input_number.veranda_lights_off_delay = {
    name = "Véranda · Lights off delay";
    icon = "mdi:timer-outline";
    # No `initial`: it would reset the value on every restart. A new
    # input_number starts at `min`, so it is set to 10 once after the first
    # deploy; a minimum of 5 keeps that first stretch harmless.
    min = 5;
    max = 120;
    step = 1;
    mode = "box";
    unit_of_measurement = "min";
  };

  automations = [
    {
      id = "dafos_veranda_lights_empty";
      alias = "Véranda · Lights off when empty";
      description = "Turns the veranda lights off once the living room radar, the veranda's switch, cube and button and daftv have all been quiet for input_number.veranda_lights_off_delay minutes. Never while daftv is on. Managed in Nix (modules/nixos/services/home-assistant/veranda_lights.nix).";
      mode = "single";
      triggers = [
        (quietFor radar)
        (quietFor tv)
        {
          trigger = "state";
          entity_id = lights;
          to = "on";
          "for" = delay;
        }
        # Catches the switch, cube and button presses getting old, and a
        # restart in the middle of a countdown.
        {
          trigger = "time_pattern";
          minutes = "/5";
        }
      ];
      conditions = [
        {
          condition = "state";
          entity_id = lights;
          state = "on";
        }
        {
          alias = "Lit for the whole delay";
          condition = "state";
          entity_id = lights;
          state = "on";
          "for" = delay;
        }
        (quietSince radar // { alias = "Nobody seen by the radar for the whole delay"; })
        (quietSince tv // { alias = "daftv off for the whole delay"; })
        {
          alias = "No veranda switch, cube or button press for the whole delay";
          condition = "template";
          value_template = ''
            {% set d = timedelta(minutes=states('${delayHelper}') | int(10)) %}
            {{ expand(${builtins.toJSON activity})
               | selectattr('last_changed', 'gt', now() - d)
               | list | count == 0 }}
          '';
        }
      ];
      actions = [
        {
          action = "light.turn_off";
          target.entity_id = lightsGroup;
        }
      ];
    }
  ];
}
