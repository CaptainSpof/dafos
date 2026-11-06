# CO2 alerts for rooms with a CO2 sensor: so far the desk, through the IKEA
# ALPSTUGA air quality monitor (Matter over Thread).
#
# Outdoor air is ~420 ppm. Above ~1000 ppm concentration drops and the room
# needs air; the alert fires at 1200 ppm held 5 min (a passing breath on the
# sensor does not count), once per episode: a numeric_state trigger only fires
# on the crossing. Back under 800 ppm for 5 min, the notification is cleared.
{ lib }:

let
  inherit (lib) map;

  rooms = [
    {
      id = "desk";
      article = "dans le bureau";
      sensor = "sensor.desk_air_quality_monitor_carbon_dioxide";
      door = "binary_sensor.desk_door_sensor_contact";
    }
  ];

  high = 1200;
  fine = 800;

  automation = r: {
    id = "dafos_co2_${r.id}";
    alias = "Air · CO2 ${r.id}";
    description = "Prévient quand le CO2 ${r.article} reste au-dessus de ${toString high} ppm, et efface la notification une fois revenu sous ${toString fine} ppm. Géré dans Nix (modules/nixos/services/home-assistant/co2.nix).";
    mode = "single";
    triggers = [
      {
        trigger = "numeric_state";
        entity_id = r.sensor;
        above = high;
        "for".minutes = 5;
        id = "high";
      }
      {
        trigger = "numeric_state";
        entity_id = r.sensor;
        below = fine;
        "for".minutes = 5;
        id = "fine";
      }
    ];
    actions = [
      {
        choose = [
          {
            alias = "Trop de CO2 : aérer la pièce";
            conditions = [
              {
                condition = "trigger";
                id = "high";
              }
            ];
            sequence = [
              {
                action = "notify.mobile_app_dafphone";
                data = {
                  title = "CO₂ élevé ${r.article}";
                  message = "{{ states('${r.sensor}') | int }} ppm. {{ 'La porte est ouverte, ouvre aussi la fenêtre.' if is_state('${r.door}', 'on') else 'Ouvre la fenêtre ou la porte quelques minutes.' }}";
                  data = {
                    tag = "co2_${r.id}";
                    group = "Maison";
                    channel = "Maison";
                    notification_icon = "mdi:molecule-co2";
                  };
                };
              }
            ];
          }
          {
            alias = "Air renouvelé : retirer l'alerte";
            conditions = [
              {
                condition = "trigger";
                id = "fine";
              }
            ];
            sequence = [
              {
                action = "notify.mobile_app_dafphone";
                data = {
                  message = "clear_notification";
                  data.tag = "co2_${r.id}";
                };
              }
            ];
          }
        ];
      }
    ];
  };
in
{
  automations = map automation rooms;
}
