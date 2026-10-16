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
  inherit (lib)
    concatMapStringsSep
    filter
    listToAttrs
    nameValuePair
    ;

  inherit (import ./rooms.nix) floors rooms;

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

  # Temperature trend for the thermostat cards. `derivative` gives °C/h over
  # half an hour; its name is ASCII so its entity id is predictable
  # (sensor.climate_rate_<id>), as YAML platform sensors take no
  # default_entity_id.
  rateSensor = r: {
    platform = "derivative";
    name = "Climate rate ${r.id}";
    unique_id = "dafos.sensor.climate_rate_${r.id}";
    source = r.temperature;
    unit_time = "h";
    time_window = "00:30:00";
    round = 2;
  };

  # The card shows this sensor's icon: rising, falling or steady, with a dead
  # band of ±0.2 °C/h so sensor noise does not flip the arrow.
  trendSensor = r: {
    name = "Climate · ${r.name} trend";
    unique_id = "dafos.sensor.climate_${r.id}_trend";
    default_entity_id = "sensor.climate_${r.id}_trend";
    unit_of_measurement = "°C/h";
    state = "{{ states('sensor.climate_rate_${r.id}') | float(0) | round(1) }}";
    availability = "{{ has_value('sensor.climate_rate_${r.id}') }}";
    icon = ''
      {% set d = states('sensor.climate_rate_${r.id}') | float(0) %}
      {{ 'mdi:arrow-top-right' if d > 0.2 else 'mdi:arrow-bottom-right' if d < -0.2 else 'mdi:arrow-right' }}
    '';
  };

  # Rows for the notifications card. It shows an input_boolean's translated
  # state ("Activé") under the name and has no option to change it, so each
  # notice is a sensor whose state is the text to show, and `off` otherwise.
  notices = [
    {
      id = "dishwasher_done";
      name = "Lave-vaisselle";
      source = "input_boolean.kitchen_dishwasher_is_finished";
      text = "Terminé";
      icon = "mdi:dishwasher";
    }
    {
      id = "washing_machine_done";
      name = "Lave-linge";
      source = "input_boolean.laundry_washing_machine_is_finished";
      text = "Terminé";
      icon = "mdi:washing-machine";
    }
    {
      id = "dryer_done";
      name = "Sèche-linge";
      source = "input_boolean.laundry_dryer_is_finished";
      text = "Terminé";
      icon = "mdi:tumble-dryer";
    }
    {
      id = "mail";
      name = "Courrier";
      source = "input_boolean.outdoor_check_mailbox";
      text = "Arrivé";
      icon = "mdi:mailbox-up";
    }
  ];

  noticeSensor = n: {
    inherit (n) name icon;
    unique_id = "dafos.sensor.maison_notice_${n.id}";
    default_entity_id = "sensor.maison_notice_${n.id}";
    state = "{{ '${n.text}' if is_state('${n.source}', 'on') else 'off' }}";
  };
in
{
  platformSensors = map rateSensor climateRooms;

  sensors =
    map climateSensor climateRooms
    ++ map trendSensor climateRooms
    ++ map noticeSensor notices
    ++ [
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
        # The small line above the greeting: the next event within a day from
        # the family or Cédric's calendar, otherwise today's date. A calendar
        # without an upcoming event has no `message`, which showed `undefined`.
        name = "Maison · Greeting subtitle";
        unique_id = "dafos.sensor.greeting_subtitle";
        default_entity_id = "sensor.greeting_subtitle";
        icon = "mdi:calendar-today";
        state = ''
          {% set ns = namespace(start=none, msg=none) %}
          {% for c in ['calendar.famille', 'calendar.dafonseca_cedric_gmail_com'] %}
            {% set s = state_attr(c, 'start_time') | as_datetime(none) %}
            {% set s = s | as_local if s is not none else none %}
            {% if s is not none and state_attr(c, 'message') and s < now() + timedelta(days=1)
                  and (ns.start is none or s < ns.start) %}
              {% set ns.start = s %}{% set ns.msg = state_attr(c, 'message') %}
            {% endif %}
          {% endfor %}
          {% if ns.msg %}
            {{ ('maintenant' if ns.start <= now() else ns.start.strftime('%H:%M')) ~ ' · ' ~ ns.msg }}
          {% else %}
            {% set days = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'] %}
            {% set months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet',
                             'août', 'septembre', 'octobre', 'novembre', 'décembre'] %}
            {{ days[now().weekday()] ~ ' ' ~ now().day ~ ' ' ~ months[now().month - 1] }}
          {% endif %}
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
    # Unfolds the plugs in a room pop-up; every pop-up turns it off on close,
    # so the plugs start folded and are not switched off by a stray tap.
    plugs_unfolded = {
      name = "Maison · Plugs unfolded";
      icon = "mdi:power-socket-eu";
    };
  }
  # Unfolds a floor's rooms; rooms with a light on show while folded too
  // listToAttrs (
    map (
      f:
      nameValuePair "maison_floor_${f.id}" {
        name = "Maison · ${f.name} unfolded";
        icon = "mdi:home-floor-${
          if f.id == "basement" then
            "negative-1"
          else if f.id == "first_floor" then
            "1"
          else
            "0"
        }";
      }
    ) floors
  );

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
