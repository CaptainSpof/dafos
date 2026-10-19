# The desk and veranda colour panels go on and off together, and the desk
# panel takes the veranda panel's colour, at 10 % brightness: the veranda shows the household
# statuses (finished appliances, mail; Véranda · Color Panel Status), so the
# desk panel shows them too.
#
# Colour flows one way only, veranda to desk. Copying it both ways bounced:
# a panel reports an intermediate state (on, still white, before its colour
# applies), the copy sent that white back and overwrote the colour.
#
# Mode restart: the veranda reports several updates while it changes; only the
# last one, 2 s later, is copied.
_:

let
  desk = "light.desk_color_panel";
  veranda = "light.veranda_color_panel";
  # The desk panel only glows: its own brightness, whatever the veranda's.
  deskBrightness = 10;
in
{
  automations = [
    {
      id = "dafos_color_panels_mirror";
      alias = "Color Panels · Mirror";
      description = "The desk and veranda colour panels turn on and off together; the desk panel takes the veranda panel's colour, at 10 % brightness. Managed in Nix (modules/nixos/services/home-assistant/color_panels.nix).";
      mode = "restart";
      triggers = [
        {
          trigger = "state";
          entity_id = [
            desk
            veranda
          ];
          from = "off";
          to = "on";
          id = "on";
        }
        {
          trigger = "state";
          entity_id = [
            desk
            veranda
          ];
          from = "on";
          to = "off";
          id = "off";
        }
        {
          trigger = "state";
          entity_id = veranda;
          attribute = "xy_color";
          id = "colour";
        }
      ];
      actions = [
        {
          choose = [
            {
              alias = "Off: the other goes off";
              conditions = [
                {
                  condition = "trigger";
                  id = "off";
                }
              ];
              sequence = [
                {
                  action = "light.turn_off";
                  target.entity_id = "{{ '${veranda}' if trigger.entity_id == '${desk}' else '${desk}' }}";
                }
              ];
            }
            {
              alias = "Desk on: the veranda comes on (its colour then flows back)";
              conditions = [
                {
                  condition = "trigger";
                  id = "on";
                }
                {
                  condition = "template";
                  value_template = "{{ trigger.entity_id == '${desk}' }}";
                }
                {
                  condition = "state";
                  entity_id = veranda;
                  state = "off";
                }
              ];
              sequence = [
                {
                  action = "light.turn_on";
                  target.entity_id = veranda;
                }
              ];
            }
            {
              alias = "Veranda on or recoloured: the desk copies the colour, at 10 %";
              conditions = [
                {
                  condition = "template";
                  value_template = "{{ trigger.entity_id == '${veranda}' and trigger.id in ['on', 'colour'] }}";
                }
                {
                  condition = "state";
                  entity_id = veranda;
                  state = "on";
                }
              ];
              sequence = [
                { delay.seconds = 2; }
                {
                  "if" = [
                    {
                      condition = "template";
                      value_template = "{{ state_attr('${veranda}', 'color_mode') == 'xy' and state_attr('${veranda}', 'xy_color') is not none }}";
                    }
                  ];
                  "then" = [
                    {
                      action = "light.turn_on";
                      target.entity_id = desk;
                      data = {
                        xy_color = "{{ state_attr('${veranda}', 'xy_color') | list }}";
                        brightness_pct = deskBrightness;
                      };
                    }
                  ];
                  "else" = [
                    {
                      action = "light.turn_on";
                      target.entity_id = desk;
                      data = {
                        color_temp_kelvin = "{{ state_attr('${veranda}', 'color_temp_kelvin') | int(3000) }}";
                        brightness_pct = deskBrightness;
                      };
                    }
                  ];
                }
              ];
            }
          ];
        }
      ];
    }
  ];
}
