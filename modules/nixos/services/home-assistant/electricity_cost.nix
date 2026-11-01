# What each metered appliance costs in electricity: today and this month, per
# device and for all of them, for the Maison dashboard's "Électricité" pop-up
# (navbar).
#
# Per device: its plug's energy today (utility_meter) × the electricity price
# (input_number.heating_electricity_price, shared with heating_cost.nix) gives
# a cost today that resets at midnight (total_increasing), so a price change
# only reprices the current day. A monthly utility_meter adds the days up, and
# the dashboard's statistics graphs sum the daily sensors with "change".
#
# The stove is here for its plug too; its pellets are in heating_cost.nix.
# laundry_plug_energy and basement_switch_energy are left out: both have
# counted nothing for a month (an old plug, a switch with nothing on it).
{ lib }:

let
  inherit (lib) concatMap concatMapStringsSep listToAttrs;

  price = "input_number.heating_electricity_price";

  # Entity ids: sensor.electricity_<id>_energy_today, _cost_today, _cost_month
  devices = [
    {
      id = "desk";
      name = "Bureau";
      energy = "sensor.desk_plug_energy";
      icon = "mdi:desk";
    }
    {
      id = "server";
      name = "Serveur";
      energy = "sensor.living_room_server_plug_energy";
      icon = "mdi:server";
    }
    {
      id = "kitchen_fridge";
      name = "Frigo cuisine";
      energy = "sensor.kitchen_fridge_plug_energy";
      icon = "mdi:fridge";
    }
    {
      id = "basement_fridge";
      name = "Frigo sous-sol";
      energy = "sensor.basement_fridge_plug_energy";
      icon = "mdi:fridge-outline";
    }
    {
      id = "dishwasher";
      name = "Lave-vaisselle";
      energy = "sensor.kitchen_dishwasher_plug_summation_delivered";
      icon = "mdi:dishwasher";
    }
    {
      id = "washing_machine";
      name = "Lave-linge";
      energy = "sensor.laundry_washing_machine_summation_delivered";
      icon = "mdi:washing-machine";
    }
    {
      id = "dryer";
      name = "Sèche-linge";
      energy = "sensor.laundry_dryer_summation_delivered";
      icon = "mdi:tumble-dryer";
    }
    {
      id = "veranda_tv";
      name = "TV véranda";
      energy = "sensor.veranda_tv_plug_summation_delivered";
      icon = "mdi:television";
    }
    {
      id = "veranda";
      name = "Prise véranda";
      energy = "sensor.veranda_plug_energy";
      icon = "mdi:power-socket-fr";
    }
    {
      id = "bed";
      name = "Lit";
      energy = "sensor.bedroom_bed_plug_energy";
      icon = "mdi:bed";
    }
    {
      id = "bedroom_ac";
      name = "Clim chambre";
      energy = "sensor.bedroom_portable_a_c_energy";
      icon = "mdi:air-conditioner";
    }
    {
      id = "stove";
      name = "Poêle (électricité)";
      energy = "sensor.living_room_stove_summation_delivered";
      icon = "mdi:fireplace";
    }
    {
      id = "battery_charger";
      name = "Chargeur de batteries";
      energy = "sensor.basement_battery_charger_energy";
      icon = "mdi:battery-charging";
    }
    {
      id = "vacuum";
      name = "Aspirateur";
      energy = "sensor.basement_vacuum_plug_energy";
      icon = "mdi:robot-vacuum";
    }
  ];

  energyToday = d: "sensor.electricity_${d.id}_energy_today";
  costToday = d: "sensor.electricity_${d.id}_cost_today";

  # No `name`: a utility_meter's entity id follows its name when it has one.
  meter = key: source: cycle: {
    name = key;
    value = { inherit source cycle; };
  };
in
{
  utility_meter = listToAttrs (
    concatMap (d: [
      (meter "electricity_${d.id}_energy_today" d.energy "daily")
      (meter "electricity_${d.id}_cost_month" (costToday d) "monthly")
    ]) devices
    ++ [ (meter "electricity_total_cost_month" "sensor.electricity_total_cost_today" "monthly") ]
  );

  templates = [
    {
      sensor =
        map (d: {
          name = "${d.name} · Coût aujourd'hui";
          unique_id = "dafos.sensor.electricity_${d.id}_cost_today";
          default_entity_id = costToday d;
          inherit (d) icon;
          unit_of_measurement = "€";
          state_class = "total_increasing";
          # The daily meter is unknown until its source first reports today
          state = "{{ (states('${energyToday d}') | float(0) * states('${price}') | float) | round(2) }}";
          availability = "{{ has_value('${price}') }}";
        }) devices
        ++ [
          {
            name = "Électricité · Coût aujourd'hui";
            unique_id = "dafos.sensor.electricity_total_cost_today";
            default_entity_id = "sensor.electricity_total_cost_today";
            icon = "mdi:lightning-bolt";
            unit_of_measurement = "€";
            state_class = "total_increasing";
            state = "{{ ((${
              concatMapStringsSep " + " (d: "states('${energyToday d}') | float(0)") devices
            }) * states('${price}') | float) | round(2) }}";
            availability = "{{ has_value('${price}') }}";
          }
        ];
    }
  ];

  inherit devices;
}
