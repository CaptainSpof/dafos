# Cédric's bedroom presence, held while the door stays shut.
#
# The SNZB-06P radar (raw) drops to off a dozen times a night while he sleeps
# or keeps still. Nobody leaves without the door, so:
#
# - latch: the radar sees someone while the door has been closed for at least
#   latchMinutes. The delay skips closing the door from outside on the way out,
#   when the radar still sees him for about a minute.
# - latched: on, whatever the radar says, until the door opens.
# - door open (or its sensor unavailable): follows the radar. After the latch
#   is released, or the radar drops, it stays on for holdMinutes past the last
#   of the door change and the last detection.
# - radar unavailable: on while latched, unavailable otherwise.
#
# Trigger-based, so HA restores the state and the `latched` attribute across
# restarts. Zigbee2MQTT republishes its states about a minute after HA starts;
# until then the door is `unknown`, which keeps the latch (`unavailable`, a
# dropped device, releases it). The minute tick catches the latch delay and the hold expiring.
# Consumers: ./bedroom_lights.nix, ./light_triggers.nix, ./origami/rooms.nix.
# "Global · Set Night State" (UI) keeps the raw radar on purpose: it wants a
# fresh detection.
_:

let
  entity = "binary_sensor.bedroom_presence";
  raw = "binary_sensor.bedroom_presence_sensor_occupancy";
  door = "binary_sensor.bedroom_door_sensor_contact";
  latchMinutes = 2;
  holdMinutes = 2;

  # Jinja shared by the state and the attribute; `this` is the previous state.
  latched = ''
    {% set d = states.${door} %}
    {% set closed = is_state('${door}', 'off') %}
    {% set keep = closed or is_state('${door}', 'unknown') %}
    {% set latched = keep and (this.attributes.get('latched', false)
         or (closed and is_state('${raw}', 'on') and now() - d.last_changed >= timedelta(minutes=${toString latchMinutes}))) %}
  '';
in
{
  inherit entity;

  templates = [
    {
      triggers = [
        {
          trigger = "state";
          entity_id = [
            raw
            door
          ];
        }
        {
          trigger = "time_pattern";
          minutes = "/1";
        }
        {
          trigger = "homeassistant";
          event = "start";
        }
      ];
      binary_sensor = [
        {
          name = "Chambre · Présence";
          unique_id = "dafos.binary_sensor.bedroom_presence";
          default_entity_id = entity;
          device_class = "occupancy";
          state = ''
            ${latched}
            {% set r = states.${raw} %}
            {% set d = states.${door} %}
            {% set last = [r.last_changed, d.last_changed] | max if r is not none and d is not none else now() %}
            {{ is_state('${raw}', 'on') or latched
               or (this.state == 'on' and now() - last < timedelta(minutes=${toString holdMinutes})) }}
          '';
          availability = ''
            {{ has_value('${raw}')
               or (states('${door}') in ['off', 'unknown'] and this.attributes.get('latched', false)) }}
          '';
          attributes.latched = ''
            ${latched}
            {{ latched }}
          '';
        }
      ];
    }
  ];
}
