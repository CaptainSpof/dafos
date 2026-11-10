# What the heating costs, boiler against stove: an estimate for today and for
# the month, for the "Coût estimé" section of the Maison dashboard's "Usage du
# chauffage" pop-up. Prices are input_numbers, set from that pop-up.
#
# Neither heater has a fuel meter, so both costs come from run time
# (heating_usage.nix):
#
# - Boiler (Viessmann Vitodens 111-W, natural gas, modulating ~3-25 kW): hours
#   heating × average gas draw while heating (input_number.heating_boiler_power,
#   kW) × gas price (€/kWh, the bill's consumption price, subscription left
#   out). The run signal is the Netatmo relay, so domestic hot water is not
#   counted. Calibrate the average draw from two gas meter readings: kWh used
#   over a week ÷ sensor.heating_boiler_week.
# - Stove: burn hours × bag price ÷ hours a bag lasts (one bag fills the tank,
#   input_number.stove_pellets_autonomy, see pellets.nix), plus the plug's
#   metered electricity today × electricity price.
#
# The utility_meter entity ids follow their keys only without a `name`.
#
# The _today sensors reset at midnight (total_increasing), so the dashboard's
# statistics graphs sum them per day or month with the "change" stat.
#
# Before/after comparisons (heating_controller.nix's stove-first changes,
# 2026-11-10): a colder week costs more whatever the controller does, so the
# weekly cost is also divided by the week's heating degree-days (base 18 °C,
# Météo-France's current temperature for Nanterre, summed every 10 min).
# Reference week 2026-11-03 → 09: boiler 46.1 h, 64.6 €; stove 37.1 h, 13.8 €;
# 80 degree-days (Open-Meteo daily means) → 0.98 €/DJ, boiler alone 0.81 €/DJ.
_:

let
  gasPrice = "input_number.heating_gas_price";
  boilerPower = "input_number.heating_boiler_power";
  electricityPrice = "input_number.heating_electricity_price";
  bagPrice = "input_number.stove_pellets_bag_price";
  autonomy = "input_number.stove_pellets_autonomy";
  stoveEnergyToday = "sensor.heating_stove_energy_today";
  outdoor = "sensor.outdoor_temperature";
  degreeDaysWeek = "sensor.heating_degree_days_week";
  base = 18; # °C, the usual French DJU base

  price = name: icon: step: unit: {
    inherit name icon step;
    min = 0;
    max = 100;
    unit_of_measurement = unit;
    mode = "box";
  };
in
{
  # No `initial`: it would reset the values on every restart.
  input_number = {
    heating_gas_price = price "Chauffage · Prix du gaz" "mdi:fire" 0.0001 "€/kWh";
    heating_electricity_price = price "Électricité · Prix du kWh" "mdi:flash" 0.0001 "€/kWh";
    stove_pellets_bag_price = price "Poêle · Prix d'un sac de granulés" "mdi:sack" 0.01 "€";
    heating_boiler_power =
      price "Chaudière · Puissance gaz moyenne en chauffe" "mdi:water-boiler" 0.5
        "kW";
  };

  utility_meter = {
    # The stove plug's energy today, for its electricity cost
    heating_stove_energy_today = {
      source = "sensor.living_room_stove_summation_delivered";
      cycle = "daily";
    };
    heating_stove_cost_month = {
      source = "sensor.heating_stove_cost_today";
      cycle = "monthly";
    };
    heating_boiler_cost_month = {
      source = "sensor.heating_boiler_cost_today";
      cycle = "monthly";
    };
    # Monday to Sunday, for the cost per degree-day
    heating_boiler_cost_week = {
      source = "sensor.heating_boiler_cost_today";
      cycle = "weekly";
    };
    heating_stove_cost_week = {
      source = "sensor.heating_stove_cost_today";
      cycle = "weekly";
    };
    heating_degree_days_week = {
      source = "sensor.heating_degree_days_today";
      cycle = "weekly";
    };
  };

  templates = [
    {
      sensor = [
        # The weather entity's temperature as a sensor, so the recorder keeps
        # long-term statistics of it
        {
          name = "Extérieur · Température";
          unique_id = "dafos.sensor.outdoor_temperature";
          default_entity_id = outdoor;
          device_class = "temperature";
          state_class = "measurement";
          unit_of_measurement = "°C";
          state = "{{ state_attr('weather.nanterre', 'temperature') }}";
          availability = "{{ state_attr('weather.nanterre', 'temperature') is number }}";
        }
        {
          name = "Chauffage · Coût par degré-jour (semaine)";
          unique_id = "dafos.sensor.heating_cost_per_degree_day_week";
          default_entity_id = "sensor.heating_cost_per_degree_day_week";
          icon = "mdi:scale-balance";
          unit_of_measurement = "€/DJ";
          state_class = "measurement";
          state = "{{ ((states('sensor.heating_boiler_cost_week') | float + states('sensor.heating_stove_cost_week') | float) / states('${degreeDaysWeek}') | float) | round(2) }}";
          availability = "{{ has_value('sensor.heating_boiler_cost_week') and has_value('sensor.heating_stove_cost_week') and states('${degreeDaysWeek}') | float(0) >= 1 }}";
          attributes = {
            boiler = "{{ (states('sensor.heating_boiler_cost_week') | float(0) / [states('${degreeDaysWeek}') | float(0), 1] | max) | round(2) }}";
            stove = "{{ (states('sensor.heating_stove_cost_week') | float(0) / [states('${degreeDaysWeek}') | float(0), 1] | max) | round(2) }}";
          };
        }
      ];
    }
    {
      # Degree-days so far today: every 10 min, add how far the outdoor
      # temperature is below the base, over a 144th of a day. Restarts at
      # midnight; trigger-based, so it survives HA restarts.
      triggers = [
        {
          trigger = "time_pattern";
          minutes = "/10";
        }
      ];
      sensor = [
        {
          name = "Chauffage · Degrés-jours aujourd'hui";
          unique_id = "dafos.sensor.heating_degree_days_today";
          default_entity_id = "sensor.heating_degree_days_today";
          icon = "mdi:thermometer-chevron-down";
          unit_of_measurement = "DJ";
          state_class = "total_increasing";
          state = ''
            {% set t = states('${outdoor}') | float(none) %}
            {% set fresh = now().hour == 0 and now().minute < 10 %}
            {% set prev = 0 if fresh or not has_value(this.entity_id) else this.state | float(0) %}
            {{ (prev + ([${toString base} - t, 0] | max / 144 if t is not none else 0)) | round(3) }}
          '';
        }
      ];
    }
    {
      sensor = [
        {
          name = "Chaudière · Coût aujourd'hui";
          unique_id = "dafos.sensor.heating_boiler_cost_today";
          default_entity_id = "sensor.heating_boiler_cost_today";
          icon = "mdi:water-boiler";
          unit_of_measurement = "€";
          state_class = "total_increasing";
          state = "{{ (states('sensor.heating_boiler_today') | float * states('${boilerPower}') | float * states('${gasPrice}') | float) | round(2) }}";
          availability = "{{ has_value('sensor.heating_boiler_today') and has_value('${boilerPower}') and has_value('${gasPrice}') }}";
        }
        {
          name = "Poêle · Coût aujourd'hui";
          unique_id = "dafos.sensor.heating_stove_cost_today";
          default_entity_id = "sensor.heating_stove_cost_today";
          icon = "mdi:fireplace";
          unit_of_measurement = "€";
          state_class = "total_increasing";
          state = ''
            {% set pellets = states('sensor.heating_stove_today') | float * states('${bagPrice}') | float / [states('${autonomy}') | float, 1] | max %}
            {% set power = states('${stoveEnergyToday}') | float(0) * states('${electricityPrice}') | float %}
            {{ (pellets + power) | round(2) }}
          '';
          availability = "{{ has_value('sensor.heating_stove_today') and has_value('${bagPrice}') and has_value('${autonomy}') and has_value('${electricityPrice}') }}";
          attributes = {
            pellets = "{{ (states('sensor.heating_stove_today') | float(0) * states('${bagPrice}') | float(0) / [states('${autonomy}') | float(0), 1] | max) | round(2) }}";
            electricity = "{{ (states('${stoveEnergyToday}') | float(0) * states('${electricityPrice}') | float(0)) | round(2) }}";
          };
        }
      ];
    }
  ];
}
