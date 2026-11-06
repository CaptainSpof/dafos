# The desk's Aqara Magic Cube (MFKZQ01LM, Zigbee2MQTT "Desk · Cube").
#
# It replaces the UI automation "Desk · Cube Controller" (luckypoppy's
# z2m-xiaomi-cube-controller blueprint), which read the cube's face from the
# action sensor's attributes. Zigbee2MQTT 2.x no longer publishes those, so
# no gesture matched and the automation had not fired since March 2025. The
# MQTT payload still carries the action and the faces, so this reads it
# directly. Gestures and their actions are the old automation's.
_:

let
  topic = "zigbee2mqtt/Desk · Cube";
  # Ceiling and desk lamp; not the colour panel, which sits in the same area.
  lights = "light.desk_all_lights";

  # A gesture, on a given face when `side` is set: Z2M reports the face as
  # `side` (`to_side` after a flip, which equals `side`).
  gesture =
    {
      alias,
      action,
      side ? null,
      sequence,
    }:
    {
      inherit alias sequence;
      conditions = [
        {
          condition = "template";
          value_template =
            "{{ trigger.payload_json.action == '${action}'"
            + (if side == null then "" else " and trigger.payload_json.side == ${toString side}")
            + " }}";
        }
      ];
    };
in
{
  automations = [
    {
      id = "dafos_desk_cube";
      alias = "Desk · Cube";
      description = "Lumières du bureau, prise du bureau et dafbox depuis le cube Aqara du bureau. Géré dans Nix (modules/nixos/services/home-assistant/desk_cube.nix).";
      mode = "queued";
      max = 10;
      triggers = [
        {
          trigger = "mqtt";
          inherit topic;
        }
      ];
      # Z2M also publishes an empty action after each gesture, and
      # battery/temperature reports without one
      conditions = [
        {
          condition = "template";
          value_template = "{{ (trigger.payload_json.action | default('')) not in ['', 'wakeup'] }}";
        }
      ];
      actions = [
        {
          choose = [
            (gesture {
              alias = "Secouer : allumer/éteindre les lumières du bureau";
              action = "shake";
              sequence = [
                {
                  action = "light.toggle";
                  target.entity_id = lights;
                }
              ];
            })
            (gesture {
              alias = "Double tape sur la face 0 : allumer/éteindre les lumières du bureau, blanc chaud à 60 %";
              action = "tap";
              side = 0;
              sequence = [
                {
                  action = "light.toggle";
                  target.entity_id = lights;
                  data = {
                    color_temp_kelvin = 2440;
                    brightness_pct = 60;
                  };
                }
              ];
            })
            (gesture {
              alias = "Double tape sur la face 1 : allumer/éteindre la prise du bureau";
              action = "tap";
              side = 1;
              sequence = [
                {
                  action = "switch.toggle";
                  target.entity_id = "switch.desk_plug";
                }
              ];
            })
            (gesture {
              alias = "Rotation à droite sur la face 0 : plus fort";
              action = "rotate_right";
              side = 0;
              sequence = [
                {
                  action = "script.increase_brightness";
                  data.light_target = lights;
                }
              ];
            })
            (gesture {
              alias = "Rotation à gauche sur la face 0 : moins fort";
              action = "rotate_left";
              side = 0;
              sequence = [
                {
                  action = "script.decrease_brightness";
                  data.light_target = lights;
                }
              ];
            })
            (gesture {
              alias = "Basculer de 90° sur la face 1 : allumer la prise du bureau, puis dafbox";
              action = "flip90";
              side = 1;
              sequence = [ { action = "script.power_on_desk_plug_and_turn_on_dafbox"; } ];
            })
          ];
        }
      ];
    }
  ];
}
