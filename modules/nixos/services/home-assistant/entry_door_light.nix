# Entry light on when the front door opens, in the dark.
#
# "Entry · Sensor Light" (UI, Blackshome blueprint) already lights the entry on
# the door or motion group and turns it off again, but it only sends turn_on to
# the lights it believes are off. On 2026-11-06 the ceiling bulbs reported "on"
# 40 ms after being turned off and HA kept that state for 15 min: the next door
# opening sent turn_on to an empty target list and the entry stayed dark.
# This automation turns the light on whatever its state says; the blueprint
# still turns it off once door and motion have been quiet.
_:

let
  door = "binary_sensor.entry_door_sensor_opening";
  light = "light.entry_ceiling_lights";
  lux = "sensor.entry_motion_sensor_illuminance";
  bypass = "input_boolean.entry_lights_bypass_toggle";
  luxThreshold = 40; # same as the blueprint
in
{
  automations = [
    {
      id = "dafos_entry_door_light";
      alias = "Entrée · Light on door open";
      description = "Allume la lumière de l'entrée à l'ouverture de la porte quand il fait sombre (soleil sous l'horizon ou luminosité sous ${toString luxThreshold} lx), même si Home Assistant la croit déjà allumée. L'extinction reste gérée par « Entry · Sensor Light ». Inactif quand le bypass de l'entrée est activé. Géré dans Nix (modules/nixos/services/home-assistant/entry_door_light.nix).";
      mode = "single";
      triggers = [
        {
          trigger = "state";
          entity_id = door;
          to = "on";
        }
      ];
      conditions = [
        {
          alias = "Bypass de l'entrée désactivé";
          condition = "state";
          entity_id = bypass;
          state = "off";
        }
        {
          alias = "Il fait sombre";
          condition = "or";
          conditions = [
            {
              condition = "state";
              entity_id = "sun.sun";
              state = "below_horizon";
            }
            {
              condition = "numeric_state";
              entity_id = lux;
              below = luxThreshold;
            }
          ];
        }
      ];
      actions = [
        {
          alias = "Allumer l'entrée, quel que soit l'état connu";
          action = "light.turn_on";
          target.entity_id = light;
        }
      ];
    }
  ];
}
