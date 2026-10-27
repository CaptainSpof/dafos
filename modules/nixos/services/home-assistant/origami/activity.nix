# Who is on each floor, in two grades, from ./rooms.nix.
#
# binary_sensor.<floor>_activity: a person, for sure. On for 15 min after a
# door of the floor opened or closed, a remote or switch was pressed, or a
# light was switched from the app (a context with a user; the lights the
# automations switch carry none, and a sensor light is not a proof). The cat
# can do none of these.
#
# binary_sensor.<floor>_motion: someone, or the cat. On while a room's motion
# or mmWave presence sensor is.
#
# The floor headers of the Maison dashboard show both, and the living room's
# night light (../light_triggers.nix) takes activity downstairs as someone up.
{ lib }:

let
  inherit (lib)
    concatMap
    filter
    optional
    ;

  inherit (import ./rooms.nix) floors rooms;

  holdMinutes = 15;
  dead = [
    "unavailable"
    "unknown"
  ];

  onFloor = f: filter (r: r.floor == f.id) rooms;
  doors = f: concatMap (r: optional (r.opening != null) r.opening) (onFloor f);
  actions = f: concatMap (r: r.activity or [ ]) (onFloor f);
  lights =
    f: concatMap (r: optional (r.light != null) r.light ++ map (l: l.entity) r.lights) (onFloor f);
  presences = f: concatMap (r: optional (r.presence != null) r.presence) (onFloor f);

  activity =
    f:
    let
      triggers =
        optional (doors f != [ ]) {
          trigger = "state";
          entity_id = doors f;
          not_from = dead;
          not_to = dead;
          id = "door";
        }
        ++ optional (actions f != [ ]) {
          trigger = "state";
          entity_id = actions f;
          not_from = dead;
          # The legacy action sensor goes back to '' after each press
          not_to = dead ++ [ "" ];
          id = "press";
        }
        ++ optional (lights f != [ ]) {
          trigger = "state";
          entity_id = lights f;
          from = [
            "on"
            "off"
          ];
          to = [
            "on"
            "off"
          ];
          id = "light";
        };
    in
    {
      inherit triggers;
      conditions = [
        {
          alias = "A light counts only when switched from the app, and not on a mere attribute change";
          condition = "template";
          value_template = ''
            {{ trigger.id != 'light'
               or (trigger.from_state.state != trigger.to_state.state
                   and trigger.to_state.context.user_id is not none) }}'';
        }
      ];
      binary_sensor = [
        {
          name = "${f.name} · Activité";
          unique_id = "dafos.binary_sensor.${f.id}_activity";
          default_entity_id = "binary_sensor.${f.id}_activity";
          device_class = "occupancy";
          icon = "mdi:account";
          state = "on";
          auto_off = "00:${toString holdMinutes}:00";
          attributes.source = "{{ state_attr(trigger.entity_id, 'friendly_name') or trigger.entity_id }}";
        }
      ];
    };

  motion = f: {
    name = "${f.name} · Mouvement";
    unique_id = "dafos.binary_sensor.${f.id}_motion";
    default_entity_id = "binary_sensor.${f.id}_motion";
    device_class = "motion";
    icon = "mdi:motion-sensor";
    state = "{{ ${builtins.toJSON (presences f)} | select('is_state', 'on') | list | count > 0 }}";
  };
in
{
  # One trigger-based block per floor (blocks with no trigger are skipped),
  # and the motion sensors in a plain one.
  templates = map activity (filter (f: (activity f).triggers != [ ]) floors) ++ [
    { binary_sensor = map motion floors; }
  ];
}
