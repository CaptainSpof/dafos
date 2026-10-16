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

  # Living room. The cat set the lights off in the evening through the
  # Everything Presence radar. The radar now lights the room only while someone
  # is likely up: in the day, or from 22:00 to 06:00 when an occupied bedroom
  # has its door open (Cédric's if he is home, the parents' if one of them is).
  # Coming down the stairs always lights it, and lets the radar hold it for
  # 20 min after.
  downstairs = "binary_sensor.stairs_going_dowstairs_sensor";
  livingRadar = "binary_sensor.everything_presence_lite_61659c_occupancy";
  eveningHour = 22;
  morningHour = 6; # the night state ends at 06:00
  downstairsHoldMinutes = 20;
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
    {
      name = "Living Room · Light presence";
      unique_id = "dafos.binary_sensor.living_room_light_presence";
      default_entity_id = "binary_sensor.living_room_light_presence";
      device_class = "occupancy";
      state = ''
        {% set home = ['home', 'House'] %}
        {% set evening = now().hour >= ${toString eveningHour} or now().hour < ${toString morningHour} %}
        {% set me_home = states('person.cedric_da_fonseca') in home %}
        {% set parents_home = states('person.joaquim_da_fonseca') in home
                              or states('person.myriam_da_fonseca') in home %}
        {% set rooms = ([] if not me_home else ['binary_sensor.bedroom_door_sensor_contact'])
                       + ([] if not parents_home else ['binary_sensor.parents_bedroom_door_sensor_contact']) %}
        {% set someone_up = not evening or rooms | count == 0
                            or rooms | select('is_state', 'on') | list | count > 0 %}
        {% set d = states.${downstairs} %}
        {% set came_down = d is not none
                           and now() - d.last_changed < timedelta(minutes=${toString downstairsHoldMinutes}) %}
        {{ is_state('${downstairs}', 'on')
           or (is_state('${livingRadar}', 'on') and (someone_up or came_down)) }}
      '';
      availability = "{{ has_value('${livingRadar}') }}";
    }
  ];
}
