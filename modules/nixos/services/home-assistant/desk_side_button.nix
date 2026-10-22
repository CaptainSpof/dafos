# The desk's IKEA BILRESA dual button (Matter over Thread, through dafpi's
# border router and Matter server), "Desk · Side Button".
#
# It does what the RODRET side switch ("Desk · Switch Desk Side") does: button
# 1 lights the desk, button 2 turns it off, holding dims, and a double press on
# button 1 powers the desk plug and wakes dafbox. The RODRET does on/off and
# dimming through a direct Zigbee bind to "Desk · Lights Group"; a Matter
# remote cannot bind into Zigbee, so here Home Assistant sends them to that
# group (one broadcast per step, not one command per bulb).
_:

let
  up = "event.desk_side_button_button_1";
  down = "event.desk_side_button_button_2";
  lights = "light.desk_lights_group";

  # Hold to dim: a step every 0.6 s until the button is released. Steps go to
  # the Zigbee group, so each one is a single broadcast; faster steps would
  # queue on the coordinator.
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
in
{
  automations = [
    {
      id = "dafos_desk_side_button";
      alias = "Desk · Side Button";
      description = "Desk lights and dafbox from the BILRESA side button, like the RODRET side switch. Managed in Nix (modules/nixos/services/home-assistant/desk_side_button.nix).";
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
          choose = [
            {
              alias = "Button 1: desk lights on";
              conditions = [ (pressed up "multi_press_1") ];
              sequence = [
                {
                  action = "light.turn_on";
                  target.entity_id = lights;
                }
              ];
            }
            {
              alias = "Button 1 twice: desk plug on, then dafbox";
              conditions = [ (pressed up "multi_press_2") ];
              sequence = [ { action = "script.power_on_desk_plug_and_turn_on_dafbox"; } ];
            }
            {
              alias = "Button 2: desk lights off";
              conditions = [ (pressed down "multi_press_1") ];
              sequence = [
                {
                  action = "light.turn_off";
                  target.entity_id = lights;
                }
              ];
            }
            {
              alias = "Hold button 1: brighter";
              conditions = [ (pressed up "long_press") ];
              sequence = [ (dim up 15) ];
            }
            {
              alias = "Hold button 2: dimmer";
              conditions = [ (pressed down "long_press") ];
              sequence = [ (dim down (-15)) ];
            }
          ];
        }
      ];
    }
  ];
}
