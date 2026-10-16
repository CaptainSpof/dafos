# Trigger sensors for the sensor-light automations (Blackshome blueprint, UI).
#
# Kitchen: the old trigger was a group "PIR motion OR mmWave radar". On
# 2026-10-16 the radar (zigbee2mqtt) reported presence without a break for
# four hours (its longest stretch over the six days before: 50 min); the group
# stayed on, the automation waited for it to clear and never re-triggered, so
# the light no longer came on. Here the PIR turns presence on, and the radar
# only holds it while the PIR has seen motion in the last 20 min: someone
# cooking without moving keeps the light, a stuck radar cannot hold the room.
_:

let
  pir = "binary_sensor.kitchen_motion_sensor_motion";
  radar = "binary_sensor.kitchen_motion_sensor_mmwave_occupancy";
  radarHoldMinutes = 20;
in
{
  binarySensors = [
    {
      name = "Kitchen · Light presence";
      unique_id = "dafos.binary_sensor.kitchen_light_presence";
      default_entity_id = "binary_sensor.kitchen_light_presence";
      device_class = "occupancy";
      # now() re-renders it every minute, so the radar hold expires on time
      state = ''
        {% set p = states.${pir} %}
        {{ is_state('${pir}', 'on')
           or (is_state('${radar}', 'on') and p is not none
               and now() - p.last_changed < timedelta(minutes=${toString radarHoldMinutes})) }}
      '';
      availability = "{{ has_value('${pir}') }}";
    }
  ];
}
