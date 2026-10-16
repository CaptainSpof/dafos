# The rooms of the Maison dashboard (Origami), grouped by floor in display
# order. Single source for the helpers in ./helpers.nix; the dashboard itself
# lives in HA storage and is generated from this file (`nix eval --json -f`).
#
# - id: the HA area id, and the suffix of the room's helpers and pop-up hash.
# - floor: one of `floors`. Each floor folds; rooms with a light on stay shown.
# - favorite: always shown on its floor, folded or not; the other rooms show
#   while folded only when lit (or their PC, TV or vacuum is on).
# - device: a PC or TV whose on state colours the card's icon (the lights tint
#   the icon's background instead).
# - light: the group behind the room card's icon colour. lights: the pop-up's
#   controls, groups only (a ceiling, not its bulbs), with French names.
# - temperature, humidity: sources of sensor.climate_<id>; null shows `?`.
# - opening: door or window contact, shown on the card and counted as open.
# - vacuum: the input_boolean that selects the room for
#   script.global_vacuum_selected_rooms, or null.
# - manual: the sensor-light blueprint's bypass for the room (lights switched on
#   by hand, motion ignored) and its Bypass Auto OFF delay in minutes. The
#   delay lives in the UI automation; keep the two in sync. The card draws a
#   ring that empties over that delay while the bypass is on.
# - presence: what the card's presence icon shows. The motion sensors use
#   their `_motion` entity (a few seconds per detection); their `_occupancy`
#   holds 10 min after the last motion. The mmWave rooms keep occupancy, and
#   outdoor has no `_motion`.
# - extras: plugs and devices for the pop-up. Never the fridges, the server
#   plug or the stove switch: nothing here is turned off by "Tout éteindre".
{
  floors = [
    {
      id = "ground_floor";
      name = "Rez-de-chaussée";
    }
    {
      id = "first_floor";
      name = "Étage";
    }
    {
      id = "basement";
      name = "Sous-sol et extérieur";
    }
  ];

  rooms = [
    {
      id = "living_room";
      floor = "ground_floor";
      name = "Salon";
      icon = "mdi:table-furniture";
      favorite = true;
      device = null;
      light = "light.living_room_ceiling_lights";
      lights = [ ];
      temperature = "sensor.living_room_current_temperature";
      humidity = null;
      opening = null;
      climate = "climate.sejour";
      presence = "binary_sensor.living_room_combined_presence_sensors";
      media = null;
      vacuum = "input_boolean.living_room_vacuum";
      manual = null;
      extras = [ "binary_sensor.living_room_stove_is_maybe_burning" ];
    }
    {
      id = "veranda";
      floor = "ground_floor";
      name = "Véranda";
      icon = "mdi:television";
      favorite = true;
      device = {
        entity = "binary_sensor.veranda_maybe_daftv_running";
        color = "var(--state-media_player-active-color)";
      };
      light = "light.veranda_all_lights";
      lights = [
        {
          entity = "light.veranda_ceiling_light";
          name = "Plafonnier";
        }
        {
          entity = "light.veranda_side_lamp_light";
          name = "Lampe d'appoint";
        }
        {
          entity = "light.veranda_tv_light";
          name = "Lampe télé";
        }
        {
          entity = "light.veranda_color_panel";
          name = "Panneau couleur";
        }
      ];
      temperature = "sensor.veranda_temperature_sensor_temperature";
      humidity = "sensor.veranda_temperature_sensor_humidity";
      opening = "binary_sensor.veranda_door_sensor_contact";
      climate = "climate.veranda_radiator";
      presence = "binary_sensor.everything_presence_lite_61659c_occupancy";
      # The Google TV Streamer (Android TV Remote), which drives daftv over CEC
      media = "media_player.televiseur_living_room_2";
      vacuum = "input_boolean.veranda_vacuum";
      manual = null;
      extras = [ ];
    }
    {
      id = "kitchen";
      floor = "ground_floor";
      name = "Cuisine";
      icon = "mdi:knife";
      favorite = false;
      device = null;
      light = "light.kitchen_all_lights";
      lights = [
        {
          entity = "light.kitchen_ceiling_lights";
          name = "Plafonnier";
        }
        {
          entity = "light.kitchen_cabinet_lights";
          name = "Lumières armoire";
        }
      ];
      temperature = "sensor.kitchen_temperature_sensor_temperature_2";
      humidity = "sensor.kitchen_temperature_sensor_humidity_2";
      opening = "binary_sensor.kitchen_door_sensor_contact";
      climate = "climate.kitchen_radiator_thermostat";
      presence = "binary_sensor.kitchen_motion_sensor_motion";
      media = null;
      vacuum = "input_boolean.kitchen_vacuum";
      manual = {
        bypass = "input_boolean.kitchen_lights_bypass_toggle";
        minutes = 60;
      };
      extras = [ "switch.kitchen_dishwasher_plug_switch" ];
    }
    {
      id = "entry";
      floor = "ground_floor";
      name = "Entrée";
      icon = "mdi:door";
      favorite = false;
      device = null;
      light = "light.entry_ceiling_lights";
      lights = [ ];
      temperature = null;
      humidity = null;
      opening = "binary_sensor.entry_door_sensor_opening";
      climate = null;
      presence = "binary_sensor.entry_motion_sensor_motion";
      media = null;
      vacuum = "input_boolean.entry_vacuum";
      manual = {
        bypass = "input_boolean.entry_lights_bypass_toggle";
        minutes = 45;
      };
      extras = [ "switch.entry_plug" ];
    }
    {
      id = "desk_ground_floor";
      floor = "ground_floor";
      name = "Bureau RdC";
      icon = "mdi:typewriter";
      favorite = false;
      device = null;
      light = null;
      lights = [ ];
      temperature = null;
      humidity = null;
      opening = null;
      climate = null;
      presence = null;
      media = null;
      vacuum = "input_boolean.study_room_vacuum";
      manual = null;
      extras = [ "vacuum.dafspi" ];
    }
    {
      id = "bedroom";
      floor = "first_floor";
      name = "Chambre";
      icon = "mdi:bed-double";
      favorite = true;
      device = null;
      light = "light.bedroom_all_lights";
      lights = [
        {
          entity = "light.bedroom_ceiling_lights";
          name = "Plafonnier";
        }
        {
          entity = "light.bedroom_bedside_lights";
          name = "Lampes de chevet";
        }
        {
          entity = "light.bedroom_strobe_lights";
          name = "Lampes Studio";
        }
      ];
      temperature = "sensor.bedroom_bed_side_temperature_sensor_temperature";
      humidity = "sensor.bedroom_bed_side_temperature_sensor_humidity";
      opening = "binary_sensor.bedroom_door_sensor_contact";
      climate = "climate.bedroom_radiator_thermostat";
      presence = null;
      media = null;
      vacuum = null;
      manual = null;
      extras = [ "switch.bedroom_bed_plug" ];
    }
    {
      id = "desk";
      floor = "first_floor";
      name = "Bureau";
      icon = "mdi:desktop-classic";
      favorite = true;
      device = {
        entity = "binary_sensor.desk_maybe_dafbox_running";
        color = "var(--state-switch-active-color)";
      };
      light = "light.desk_all_lights";
      lights = [
        {
          entity = "light.desk_ceiling_lights";
          name = "Plafonnier";
        }
        {
          entity = "light.desk_desk_light";
          name = "Lampe de bureau";
        }
        {
          entity = "light.desk_color_panel";
          name = "Panneau couleur";
        }
      ];
      temperature = "sensor.desk_current_temperature";
      humidity = null;
      opening = "binary_sensor.desk_door_sensor_contact";
      climate = "climate.desk_radiator_thermostat";
      presence = null;
      media = null;
      vacuum = null;
      manual = null;
      extras = [
        "switch.desk_plug"
        "button.wake_on_lan_dafbox"
      ];
    }
    {
      id = "parent_s_bedroom";
      floor = "first_floor";
      name = "Chambre Parents";
      icon = "mdi:bed-king";
      favorite = false;
      device = null;
      light = null;
      lights = [ ];
      temperature = "sensor.parents_bedroom_current_temperature";
      humidity = null;
      opening = "binary_sensor.parents_bedroom_door_sensor_contact";
      climate = "climate.parents_bedroom_radiator";
      presence = null;
      media = null;
      vacuum = null;
      manual = null;
      extras = [ ];
    }
    {
      id = "bathroom";
      floor = "first_floor";
      name = "Salle de bain";
      icon = "mdi:shower";
      favorite = false;
      device = null;
      light = null;
      lights = [ ];
      # The room sensor is often offline; the radiator's own probe always reports.
      temperature = "sensor.bathroom_radiator_local_temperature";
      humidity = "sensor.bathroom_temperature_sensor_humidity";
      opening = null;
      climate = "climate.bathroom_radiator";
      presence = null;
      media = null;
      vacuum = null;
      manual = null;
      extras = [ ];
    }
    {
      id = "stairs";
      floor = "first_floor";
      name = "Escaliers";
      icon = "mdi:stairs";
      favorite = false;
      device = null;
      light = "light.stairs_ceiling_lights";
      lights = [ ];
      temperature = null;
      humidity = null;
      opening = null;
      climate = null;
      presence = "binary_sensor.stairs_motion_sensor_upstairs_motion";
      media = null;
      vacuum = null;
      manual = {
        bypass = "input_boolean.stairs_bypass_toggle";
        minutes = 25;
      };
      extras = [ ];
    }
    {
      id = "laundry";
      floor = "basement";
      name = "Buanderie";
      icon = "mdi:washing-machine";
      favorite = false;
      device = null;
      light = null;
      lights = [ ];
      temperature = "sensor.laundry_humidity_sensor_temperature";
      humidity = "sensor.laundry_humidity_sensor_humidity";
      opening = null;
      climate = null;
      presence = null;
      media = null;
      vacuum = null;
      manual = null;
      extras = [ ];
    }
    {
      id = "outdoor";
      floor = "basement";
      name = "Palier";
      icon = "mdi:coach-lamp";
      favorite = false;
      device = null;
      light = "light.outdoor_ceiling_light";
      lights = [ ];
      temperature = null;
      humidity = null;
      opening = null;
      climate = null;
      presence = "binary_sensor.outdoor_motion_sensor_occupancy";
      media = null;
      vacuum = null;
      manual = null;
      extras = [ ];
    }
  ];
}
