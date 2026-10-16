# Indoor air quality for the kitchen and the veranda: their air sensors report
# PM2.5 and a VOC index (Sensirion scale 1-500, 100 = the sensor's own 24 h
# average). Cooking drives both: over two weeks of history the hourly peaks
# reached VOC 500 and PM2.5 989 µg/m³, and 10 % of hours peaked above VOC
# ~430 / PM2.5 ~50. Notifications are therefore per episode, not per reading.
{ lib }:

let
  inherit (lib) concatMap map;

  rooms = [
    {
      id = "kitchen";
      name = "Cuisine";
      article = "dans la cuisine";
      prefix = "sensor.kitchen_air_sensor";
      # The kitchen door is not known to lead outside: no "already aired" check.
      opening = null;
    }
    {
      id = "veranda";
      name = "Véranda";
      article = "dans la véranda";
      prefix = "sensor.veranda_temperature_sensor";
      opening = "binary_sensor.veranda_door_sensor_contact";
    }
  ];

  # Poor air: either reading over its threshold, held 5 min so a passing whiff
  # does not count, and 15 min under them before the episode ends.
  vocPoor = 250;
  pmPoor = 35;
  # Good air, for the level sensor (WHO 24 h PM2.5 guideline: 15 µg/m³).
  vocGood = 150;
  pmGood = 15;

  voc = r: "${r.prefix}_voc_index";
  pm = r: "${r.prefix}_pm2_5";
  poor = r: "binary_sensor.${r.id}_air_quality_poor";
  notified = r: "input_boolean.${r.id}_air_quality_notified";
  values =
    r:
    "{{ states('${pm r}') | float(0) | round(0) | int }} µg/m³ de particules, indice COV {{ states('${voc r}') | float(0) | round(0) | int }}";

  notify = data: {
    action = "notify.mobile_app_dafphone";
    inherit data;
  };
in
{
  binarySensors = map (r: {
    name = "${r.name} · Air quality poor";
    unique_id = "dafos.binary_sensor.${r.id}_air_quality_poor";
    default_entity_id = poor r;
    device_class = "problem";
    state = "{{ states('${voc r}') | float(0) >= ${toString vocPoor} or states('${pm r}') | float(0) >= ${toString pmPoor} }}";
    availability = "{{ has_value('${voc r}') or has_value('${pm r}') }}";
    delay_on.minutes = 5;
    delay_off.minutes = 15;
    icon = "mdi:air-filter";
  }) rooms;

  sensors = map (r: {
    name = "${r.name} · Air quality";
    unique_id = "dafos.sensor.${r.id}_air_quality";
    default_entity_id = "sensor.${r.id}_air_quality";
    icon = "mdi:air-filter";
    state = ''
      {% set v = states('${voc r}') | float(0) %}
      {% set p = states('${pm r}') | float(0) %}
      {% if v >= ${toString vocPoor} or p >= ${toString pmPoor} %}Mauvaise
      {% elif v >= ${toString vocGood} or p >= ${toString pmGood} %}Moyenne
      {% else %}Bonne{% endif %}
    '';
    availability = "{{ has_value('${voc r}') or has_value('${pm r}') }}";
    attributes = {
      voc_index = "{{ states('${voc r}') | float(0) | round(0) | int }}";
      pm2_5 = "{{ states('${pm r}') | float(0) | round(0) | int }}";
    };
  }) rooms;

  # Whether the "open the windows" notification went out for the current
  # episode, so "you can close" only follows one that was sent.
  input_boolean = builtins.listToAttrs (
    map (r: {
      name = "${r.id}_air_quality_notified";
      value = {
        name = "${r.name} · Air quality notified";
        icon = "mdi:bell-check-outline";
      };
    }) rooms
  );

  automations = [
    {
      id = "dafos_household_air_quality";
      alias = "Household · Air Quality";
      description = "Kitchen and veranda air: asks to open the windows when an episode of poor air starts (VOC index >= ${toString vocPoor} or PM2.5 >= ${toString pmPoor} for 5 min), then says the windows can be closed once it ended. Only while someone is home and outside the night state. Managed in Nix (modules/nixos/services/home-assistant/air_quality.nix).";
      mode = "queued";
      triggers = concatMap (r: [
        {
          trigger = "state";
          entity_id = poor r;
          from = "off";
          to = "on";
          id = "${r.id}-poor";
        }
        {
          trigger = "state";
          entity_id = poor r;
          from = "on";
          to = "off";
          id = "${r.id}-clean";
        }
      ]) rooms;
      actions = [
        {
          choose = concatMap (r: [
            {
              alias = "${r.name}: poor air, ask to open the windows";
              conditions = [
                {
                  condition = "trigger";
                  id = "${r.id}-poor";
                }
                {
                  condition = "state";
                  entity_id = "binary_sensor.global_home_is_occupied";
                  state = "on";
                }
                {
                  condition = "state";
                  entity_id = "binary_sensor.global_night_state";
                  state = "off";
                }
              ]
              ++ lib.optional (r.opening != null) {
                alias = "Not already aired";
                condition = "state";
                entity_id = r.opening;
                state = "off";
              };
              sequence = [
                (notify {
                  title = "Air chargé ${r.article}";
                  message = "${values r}. Ouvre les fenêtres.";
                  data = {
                    tag = "air_quality_${r.id}";
                    group = "Maison";
                    channel = "household";
                    notification_icon = "mdi:air-filter";
                  };
                })
                {
                  action = "input_boolean.turn_on";
                  target.entity_id = notified r;
                }
              ];
            }
            {
              alias = "${r.name}: air back to normal, the windows can be closed";
              conditions = [
                {
                  condition = "trigger";
                  id = "${r.id}-clean";
                }
                {
                  condition = "state";
                  entity_id = notified r;
                  state = "on";
                }
              ];
              sequence = [
                {
                  action = "input_boolean.turn_off";
                  target.entity_id = notified r;
                }
                # Same tag: replaces the "open" notification, gone after 30 min.
                (notify {
                  title = "Air redevenu sain ${r.article}";
                  message = "${values r}. Tu peux refermer les fenêtres.";
                  data = {
                    tag = "air_quality_${r.id}";
                    group = "Maison";
                    channel = "household";
                    notification_icon = "mdi:air-filter";
                    timeout = 1800;
                  };
                })
              ];
            }
          ]) rooms;
        }
      ];
    }
  ];
}
