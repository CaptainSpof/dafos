# The rooms of the Maison dashboard (Origami), in display order. Single source
# for the `sensor.climate_<id>` helpers in ./helpers.nix; the dashboard itself
# lives in HA storage and is generated from this table (`nix eval` it to JSON).
#
# - id: the HA area id, and the suffix of the room's helpers and pop-up hash.
# - pinned: shown without "Toutes les pièces". Origami's layout expects four.
# - light: the group behind the room card's icon colour; lights: its pop-up.
# - temperature, humidity: sources of sensor.climate_<id>; null shows `?`.
# - opening: door or window contact, shown on the card and counted as open.
# - extras: plugs and devices for the pop-up. Never the fridges, the server
#   plug or the stove switch: nothing here is turned off by "Tout éteindre".
[
  {
    id = "living_room";
    name = "Salon";
    icon = "mdi:sofa";
    pinned = true;
    light = "light.living_room_ceiling_lights";
    lights = [
      "light.living_room_ceiling_left_light"
      "light.living_room_ceiling_right_light"
    ];
    temperature = "sensor.living_room_current_temperature";
    humidity = null;
    opening = null;
    climate = "climate.sejour";
    presence = "binary_sensor.living_room_combined_presence_sensors";
    media = null;
    extras = [ "binary_sensor.living_room_stove_is_maybe_burning" ];
  }
  {
    id = "veranda";
    name = "Véranda";
    icon = "mdi:television";
    pinned = true;
    light = "light.veranda_all_lights";
    lights = [
      "light.veranda_ceiling_light"
      "light.veranda_side_lamp_light"
      "light.veranda_tv_light"
      "light.veranda_color_panel"
    ];
    temperature = "sensor.veranda_temperature_sensor_temperature";
    humidity = "sensor.veranda_temperature_sensor_humidity";
    opening = "binary_sensor.veranda_door_sensor_contact";
    climate = "climate.veranda_radiator";
    presence = "binary_sensor.everything_presence_lite_61659c_occupancy";
    media = "media_player.daftv";
    extras = [ ];
  }
  {
    id = "kitchen";
    name = "Cuisine";
    icon = "mdi:silverware-fork-knife";
    pinned = true;
    light = "light.kitchen_all_lights";
    lights = [
      "light.kitchen_ceiling_1_light"
      "light.kitchen_ceiling_2_light"
      "light.kitchen_ceiling_3_light"
      "light.kitchen_cabinet_lights"
    ];
    temperature = "sensor.kitchen_temperature_sensor_temperature_2";
    humidity = "sensor.kitchen_temperature_sensor_humidity_2";
    opening = "binary_sensor.kitchen_door_sensor_contact";
    climate = "climate.kitchen_radiator_thermostat";
    presence = "binary_sensor.kitchen_motion_sensor_occupancy";
    media = null;
    extras = [ "switch.kitchen_dishwasher_plug_switch" ];
  }
  {
    id = "bedroom";
    name = "Chambre";
    icon = "mdi:bed";
    pinned = true;
    light = "light.bedroom_all_lights";
    lights = [
      "light.bedroom_ceiling_1_light"
      "light.bedroom_ceiling_2_light"
      "light.bedroom_ceiling_3_light"
      "light.bedroom_bedside_left_light"
      "light.bedroom_bedside_right_light"
      "light.bedroom_strobe_lights"
    ];
    temperature = "sensor.bedroom_bed_side_temperature_sensor_temperature";
    humidity = "sensor.bedroom_bed_side_temperature_sensor_humidity";
    opening = "binary_sensor.bedroom_door_sensor_contact";
    climate = "climate.bedroom_radiator_thermostat";
    presence = null;
    media = null;
    extras = [ "switch.bedroom_bed_plug" ];
  }
  {
    id = "desk";
    name = "Bureau";
    icon = "mdi:desk";
    pinned = false;
    light = "light.desk_all_lights";
    lights = [
      "light.desk_ceiling_1_light"
      "light.desk_ceiling_2_light"
      "light.desk_ceiling_3_light"
      "light.desk_desk_light"
      "light.desk_color_panel"
    ];
    temperature = "sensor.desk_current_temperature";
    humidity = null;
    opening = "binary_sensor.desk_door_sensor_contact";
    climate = "climate.desk_radiator_thermostat";
    presence = null;
    media = null;
    extras = [
      "switch.desk_plug"
      "button.wake_on_lan_dafbox"
    ];
  }
  {
    id = "entry";
    name = "Entrée";
    icon = "mdi:door";
    pinned = false;
    light = "light.entry_ceiling_lights";
    lights = [
      "light.entry_ceiling_1_light"
      "light.entry_ceiling_2_light"
      "light.entry_ceiling_3_light"
    ];
    temperature = null;
    humidity = null;
    opening = "binary_sensor.entry_door_sensor_opening";
    climate = null;
    presence = "binary_sensor.entry_motion_sensor_occupancy";
    media = null;
    extras = [ "switch.entry_plug" ];
  }
  {
    id = "parent_s_bedroom";
    name = "Chambre Parents";
    icon = "mdi:bed-king";
    pinned = false;
    light = null;
    lights = [ ];
    temperature = "sensor.parents_bedroom_current_temperature";
    humidity = null;
    opening = "binary_sensor.parents_bedroom_door_sensor_contact";
    climate = "climate.parents_bedroom_radiator";
    presence = null;
    media = null;
    extras = [ ];
  }
  {
    id = "bathroom";
    name = "Salle de bain";
    icon = "mdi:shower";
    pinned = false;
    light = null;
    lights = [ ];
    # The room sensor is often offline; the radiator's own probe always reports.
    temperature = "sensor.bathroom_radiator_local_temperature";
    humidity = "sensor.bathroom_temperature_sensor_humidity";
    opening = null;
    climate = "climate.bathroom_radiator";
    presence = null;
    media = null;
    extras = [ ];
  }
  {
    id = "stairs";
    name = "Escaliers";
    icon = "mdi:stairs";
    pinned = false;
    light = "light.stairs_ceiling_lights";
    lights = [
      "light.stairs_ceiling_1_light"
      "light.stairs_ceiling_2_light"
      "light.stairs_ceiling_3_light"
      "light.stairs_ceiling_4_light"
    ];
    temperature = null;
    humidity = null;
    opening = null;
    climate = null;
    presence = "binary_sensor.stairs_motion_sensor_upstairs_occupancy";
    media = null;
    extras = [ ];
  }
  {
    id = "laundry";
    name = "Buanderie";
    icon = "mdi:washing-machine";
    pinned = false;
    light = null;
    lights = [ ];
    temperature = "sensor.laundry_humidity_sensor_temperature";
    humidity = "sensor.laundry_humidity_sensor_humidity";
    opening = null;
    climate = null;
    presence = null;
    media = null;
    extras = [ ];
  }
  {
    id = "desk_ground_floor";
    name = "Bureau RdC";
    icon = "mdi:robot-vacuum";
    pinned = false;
    light = null;
    lights = [ ];
    temperature = null;
    humidity = null;
    opening = null;
    climate = null;
    presence = null;
    media = null;
    extras = [ "vacuum.dafspi" ];
  }
  {
    id = "outdoor";
    name = "Extérieur";
    icon = "mdi:tree";
    pinned = false;
    light = "light.outdoor_ceiling_light";
    lights = [ ];
    temperature = null;
    humidity = null;
    opening = null;
    climate = null;
    presence = "binary_sensor.outdoor_motion_sensor_occupancy";
    media = null;
    extras = [ ];
  }
]
