# Cédric's bedroom lights go off once the room has been empty for a while.
#
# Empty is the presence sensor (SNZB-06P, mmWave) seeing nobody. Motion is no
# proof that someone is there (the cat), but a radar seeing nothing for
# 10 min is a fair proof that nobody is, since mmWave also picks up someone
# keeping still. If it ever misses someone in bed, raise emptyMinutes.
# A light switched on while the room is already empty goes off after the
# same 10 min. Nothing happens while the sensor is unavailable.
_:

let
  presence = "binary_sensor.bedroom_presence_sensor_occupancy";
  lights = "light.bedroom_all_lights";
  emptyMinutes = 10;
  delay = "00:${toString emptyMinutes}:00";
in
{
  automations = [
    {
      id = "dafos_bedroom_lights_empty";
      alias = "Bedroom · Lights off when empty";
      description = "Éteint les lumières de la chambre quand son capteur de présence n'a vu personne depuis ${toString emptyMinutes} min. Géré dans Nix (modules/nixos/services/home-assistant/bedroom_lights.nix).";
      mode = "single";
      triggers = [
        {
          trigger = "state";
          entity_id = presence;
          to = "off";
          "for" = delay;
        }
        {
          trigger = "state";
          entity_id = lights;
          to = "on";
          "for" = delay;
        }
      ];
      conditions = [
        {
          condition = "state";
          entity_id = lights;
          state = "on";
        }
        {
          alias = "Personne vu pendant tout le délai";
          condition = "state";
          entity_id = presence;
          state = "off";
          "for" = delay;
        }
      ];
      actions = [
        {
          action = "light.turn_off";
          target.entity_id = lights;
        }
      ];
    }
  ];
}
