# Helpers of the Maison dashboard, ported from Origami's packages/origami.yaml
# and generated from ./rooms.nix. The entity ids match the ones Origami's
# dashboard reads (sensor.climate_<id>, sensor.climate_home, ...).
#
# Not ported: the speaker, TV and fan helpers (no matching hardware) and
# Origami's `room_off` script, which turns off every switch in an area and here
# would cut the fridges and the server plug. The pop-ups turn off the room's
# lights and media player directly instead.
{ lib }:

let
  inherit (lib) concatMapStringsSep filter;

  rooms = import ./rooms.nix;

  climateRooms = filter (r: r.temperature != null) rooms;
  humidityRooms = filter (r: r.humidity != null) rooms;

  # A Jinja list of [entity, room id] pairs.
  pairs = attr: list: "[" + concatMapStringsSep ", " (r: "('${r.${attr}}', '${r.id}')") list + "]";

  # Name of the room with the highest value, `lowest` attribute for the lowest.
  # 'none' while fewer than two rooms report or all report the same value.
  peak = attr: list: fn: ''
    {% set ns = namespace(p=[]) %}
    {% for e, r in ${pairs attr list} %}
      {% set v = states(e) | float(none) %}
      {% if v is not none %}{% set ns.p = ns.p + [(v, r)] %}{% endif %}
    {% endfor %}
    {{ (ns.p | ${fn})[1] if ns.p | count > 1 and (ns.p | max)[0] > (ns.p | min)[0] else 'none' }}
  '';

  average = attr: list: digits: ''
    {% set v = ${builtins.toJSON (map (r: r.${attr}) list)} | map('states')
       | map('float', none) | reject('none') | list %}
    {{ (v | sum / v | count) | round(${toString digits}) if v else none }}
  '';

  rounded = entity: digits: fallback: ''
    {% set v = states('${entity}') | float(none) %}
    {{ v | round(${toString digits}) ${
      lib.optionalString (digits == 0) "| int "
    }if v is not none else '${fallback}' }}
  '';

  # Origami's comfort colour, blue at 12° to red above 32°.
  colorCode = entity: ''
    {% set t = states('${entity}') | float(20) %}
    {% set scale = [(12, '114, 143, 168'), (15, '124, 151, 169'), (17, '139, 162, 168'),
       (18.5, '154, 174, 163'), (22, '136, 163, 126'), (24, '153, 166, 119'),
       (25, '174, 167, 111'), (26, '187, 159, 104'), (27, '192, 147, 95'),
       (28, '191, 138, 95'), (29, '187, 126, 93'), (30.5, '179, 115, 92'),
       (32, '170, 106, 90'), (99, '156, 96, 86')] %}
    rgba({{ (scale | selectattr(0, '>=', t) | first)[1] }}, 0.7)
  '';

  climateSensor = r: {
    name = "Climate · ${r.name}";
    unique_id = "dafos.sensor.climate_${r.id}";
    default_entity_id = "sensor.climate_${r.id}";
    icon = "mdi:thermometer";
    state = rounded r.temperature 1 "?";
    attributes = {
      temperature = rounded r.temperature 0 "?";
      humidity = if r.humidity == null then "?" else rounded r.humidity 0 "?";
      temp_rank = ''
        {{ 'warmest' if is_state('sensor.climate_temperature_peaks', '${r.id}')
           else 'coldest' if is_state_attr('sensor.climate_temperature_peaks', 'lowest', '${r.id}')
           else 'normal' }}
      '';
      humidity_rank = ''
        {{ 'most_humid' if is_state('sensor.climate_humidity_peaks', '${r.id}')
           else 'driest' if is_state_attr('sensor.climate_humidity_peaks', 'lowest', '${r.id}')
           else 'normal' }}
      '';
      color_code = colorCode r.temperature;
    };
  };

  openings = filter (o: o != null) (map (r: r.opening) rooms);
in
{
  sensors = map climateSensor climateRooms ++ [
    {
      name = "Climate · Temperature peaks";
      unique_id = "dafos.sensor.climate_temperature_peaks";
      default_entity_id = "sensor.climate_temperature_peaks";
      icon = "mdi:thermometer";
      state = peak "temperature" climateRooms "max";
      attributes.lowest = peak "temperature" climateRooms "min";
    }
    {
      name = "Climate · Humidity peaks";
      unique_id = "dafos.sensor.climate_humidity_peaks";
      default_entity_id = "sensor.climate_humidity_peaks";
      icon = "mdi:water-percent";
      state = peak "humidity" humidityRooms "max";
      attributes.lowest = peak "humidity" humidityRooms "min";
    }
    {
      name = "Climate · Temperature average";
      unique_id = "dafos.sensor.temperature_average";
      default_entity_id = "sensor.temperature_average";
      unit_of_measurement = "°C";
      device_class = "temperature";
      state = average "temperature" climateRooms 1;
    }
    {
      name = "Climate · Humidity average";
      unique_id = "dafos.sensor.humidity_average";
      default_entity_id = "sensor.humidity_average";
      unit_of_measurement = "%";
      device_class = "humidity";
      state = average "humidity" humidityRooms 0;
    }
    {
      name = "Climate · Home";
      unique_id = "dafos.sensor.climate_home";
      default_entity_id = "sensor.climate_home";
      icon = "mdi:home-thermometer";
      state = rounded "sensor.temperature_average" 1 "?";
      attributes = {
        temperature_average = rounded "sensor.temperature_average" 0 "?";
        humidity_average = rounded "sensor.humidity_average" 0 "?";
        windows_open = ''
          {% set w = states('sensor.windows_open_count') %}
          {{ '?' if w in ['unknown', 'unavailable'] else w }}
        '';
        front_door_open = "{{ states('binary_sensor.entry_door_sensor_opening') }}";
      };
    }
    {
      # Doors, really: the house has no window contacts. Same list as the
      # room cards, so the header count matches what the cards show.
      name = "Climate · Openings open count";
      unique_id = "dafos.sensor.windows_open_count";
      default_entity_id = "sensor.windows_open_count";
      icon = "mdi:door-open";
      state = ''
        {{ ${builtins.toJSON openings} | select('is_state', 'on') | list | count }}
      '';
    }
    {
      # Origami counts zone.home, which never drops below 1 here: the kiosk
      # iPad's GPS sits inside the zone. Real people only, like
      # binary_sensor.global_maybe_home_occupied.
      name = "Maison · People home";
      unique_id = "dafos.sensor.people_home_count";
      default_entity_id = "sensor.people_home_count";
      icon = "mdi:account-group-outline";
      state = ''
        {{ states.person | rejectattr('entity_id', 'in', ['person.kiosk', 'person.daf'])
           | selectattr('state', 'in', ['home', 'House']) | list | count }}
      '';
      # Same reason as the occupancy sensor: no false 0 while persons load.
      availability = ''
        {{ states.person | rejectattr('entity_id', 'in', ['person.kiosk', 'person.daf']) | list | count > 0 }}
      '';
    }
    {
      name = "Greetings";
      unique_id = "dafos.sensor.greetings";
      default_entity_id = "sensor.greetings";
      icon = "mdi:hand-wave";
      state = ''
        {% set h = now().hour %}
        {% if h < 5 %}encore debout ?
        {% elif h < 12 %}bonjour
        {% elif h < 18 %}bon après-midi
        {% elif h < 22 %}bonsoir
        {% else %}bonne nuit{% endif %}
      '';
    }
  ];

  input_boolean = {
    # Opens the climate table under the rooms header
    room_climate_card = {
      name = "Maison · Room climate table";
      icon = "mdi:table";
    };
    # Shows the rooms beyond the pinned ones
    all_rooms = {
      name = "Maison · All rooms";
      icon = "mdi:home-group";
    };
  };

  scripts = {
    # The plus and minus buttons of the thermostat rows
    thermostat_step = {
      alias = "Thermostat step";
      description = "Moves a thermostat's target temperature up or down.";
      mode = "queued";
      fields = {
        thermostat = {
          description = "The thermostat";
          example = "climate.sejour";
          selector.entity.domain = "climate";
        };
        step = {
          description = "How far, in degrees";
          example = -0.5;
        };
      };
      sequence = [
        {
          action = "climate.set_temperature";
          target.entity_id = "{{ thermostat }}";
          data.temperature = ''
            {% set t = state_attr(thermostat, 'temperature') | float(20) + step | float(0) %}
            {{ [[t, state_attr(thermostat, 'min_temp') | float(7)] | max, state_attr(thermostat, 'max_temp') | float(35)] | min }}
          '';
        }
      ];
    };
  };

  # For the dashboard generator: `nix eval --json` this attribute.
  inherit rooms;
}
