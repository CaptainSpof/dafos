# IKEA BILRESA dual buttons (Matter over Thread, through dafpi's border router
# and Matter server). Each mirrors a Zigbee RODRET switch in the same room.
#
# The RODRETs do on/off and dimming through a direct Zigbee bind to their
# room's Zigbee2MQTT group; a Matter remote cannot bind into Zigbee, so here
# Home Assistant sends the same commands to that group (one broadcast per
# step, not one command per bulb). Button 1 is the "on" button, button 2 the
# "off" one; each fires multi_press_1, multi_press_2, long_press and
# long_release events.
_:

let
  buttons = [
    {
      # Like "Desk · Switch Desk Side" (RODRET), since 2026-10-22
      id = "desk_side_button";
      alias = "Desk · Side Button";
      lights = "light.desk_lights_group";
      onDouble = [ { action = "script.power_on_desk_plug_and_turn_on_dafbox"; } ];
    }
    {
      # Like "Véranda · Switch" (RODRET) and its "Véranda · Switch Extras"
      # automation, since 2026-10-23
      id = "veranda_button";
      alias = "Véranda · Button";
      lights = "light.veranda_lights_group";
      onDouble = [ { action = "script.turn_on_and_setup_living_room_tv"; } ];
      # A first press turns the veranda off; once it is off, the next one turns
      # the living room ceiling off too
      off = [
        {
          "if" = [
            {
              condition = "state";
              entity_id = "light.veranda_lights_group";
              state = "on";
            }
          ];
          "then" = [
            {
              action = "light.turn_off";
              target.entity_id = "light.veranda_lights_group";
            }
          ];
          "else" = [
            {
              action = "light.turn_off";
              target.entity_id = "light.living_room_ceiling_lights";
            }
          ];
        }
      ];
      offDouble = [
        {
          action = "light.turn_off";
          target.entity_id = [
            "light.veranda_all_lights"
            "light.living_room_ceiling_lights"
          ];
        }
      ];
    }
  ];

  automation =
    {
      id,
      alias,
      lights,
      onDouble ? [ ],
      off ? [
        {
          action = "light.turn_off";
          target.entity_id = lights;
        }
      ],
      offDouble ? [ ],
    }:
    let
      up = "event.${id}_button_1";
      down = "event.${id}_button_2";

      # Hold to dim: a step every 0.6 s until the button is released. Steps go
      # to the Zigbee group, so each one is a single broadcast; faster steps
      # would queue on the coordinator.
      dim = button: step: {
        repeat = {
          sequence = [
            {
              action = "light.turn_on";
              target.entity_id = lights;
              data = {
                brightness_step_pct = step;
                transition = 0.5;
              };
            }
            { delay.milliseconds = 600; }
          ];
          until = [
            {
              condition = "template";
              value_template = "{{ state_attr('${button}', 'event_type') == 'long_release' or repeat.index >= 8 }}";
            }
          ];
        };
      };

      pressed = button: event: {
        condition = "template";
        value_template = "{{ trigger.entity_id == '${button}' and trigger.to_state.attributes.event_type == '${event}' }}";
      };

      branch = alias: button: event: sequence: {
        inherit alias sequence;
        conditions = [ (pressed button event) ];
      };
    in
    {
      id = "dafos_${id}";
      inherit alias;
      description = "${alias}: lights on/off and dimming like the room's RODRET switch, plus its double presses. Managed in Nix (modules/nixos/services/home-assistant/bilresa.nix).";
      # A new press stops a running dim
      mode = "restart";
      triggers = [
        {
          trigger = "state";
          entity_id = [
            up
            down
          ];
          not_from = [ "unavailable" ];
          not_to = [ "unavailable" ];
        }
      ];
      actions = [
        {
          # A gesture with nothing to do gets no branch
          choose = builtins.filter (b: b.sequence != [ ]) [
            (branch "Button 1: lights on" up "multi_press_1" [
              {
                action = "light.turn_on";
                target.entity_id = lights;
              }
            ])
            (branch "Button 1 twice" up "multi_press_2" onDouble)
            (branch "Button 2: lights off" down "multi_press_1" off)
            (branch "Button 2 twice" down "multi_press_2" offDouble)
            (branch "Hold button 1: brighter" up "long_press" [ (dim up 15) ])
            (branch "Hold button 2: dimmer" down "long_press" [ (dim down (-15)) ])
          ];
        }
      ];
    };
in
{
  automations = map automation buttons;
}
