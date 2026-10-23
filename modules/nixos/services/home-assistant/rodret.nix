# The extra actions of the IKEA RODRET switches, read from their Zigbee2MQTT
# messages. Their on/off and dimming go through a direct Zigbee bind to the
# room's group and need nothing here; Home Assistant only adds double presses
# and the veranda's "off again: living room off".
#
# They replace UI automations built on the damru and EPMatt blueprints
# (2026-10-23): damru's derived the Zigbee address from the device for ZHA and
# logged "list object has no element 1 … ieee_id_long" on every press.
#
# A RODRET has no double press of its own: a press waits `window` for a second
# one. The automation is `single`, so the second press does not start a new
# run; the waiting one catches it.
_:

let
  window = 600; # ms between the two presses of a double press

  switches = [
    {
      id = "desk_switch";
      alias = "Desk · Switch";
      onDouble = [ { action = "script.power_on_desk_plug_and_turn_on_dafbox"; } ];
    }
    {
      id = "desk_switch_desk_side";
      alias = "Desk · Switch Desk Side";
      onDouble = [ { action = "script.power_on_desk_plug_and_turn_on_dafbox"; } ];
    }
    {
      id = "veranda_switch";
      alias = "Véranda · Switch";
      onDouble = [ { action = "script.turn_on_and_setup_living_room_tv"; } ];
      offDouble = [
        {
          action = "light.turn_off";
          target.entity_id = [
            "light.veranda_all_lights"
            "light.living_room_ceiling_lights"
          ];
        }
      ];
      # The press itself turns the veranda off through the bind; when it was
      # already off before this press (1.2 s: the double-press window plus
      # margin), turn the living room ceiling off too
      off = [
        {
          "if" = [
            {
              condition = "state";
              entity_id = "light.veranda_ceiling_light";
              state = "off";
              "for".milliseconds = 1200;
            }
          ];
          "then" = [
            {
              action = "light.turn_off";
              target.entity_id = "light.living_room_ceiling_lights";
            }
          ];
        }
      ];
    }
  ];

  automation =
    {
      id,
      alias,
      onDouble ? [ ],
      offDouble ? [ ],
      on ? [ ],
      off ? [ ],
    }:
    let
      topic = "zigbee2mqtt/${alias}";

      # The second press of the same button within the window
      again = button: {
        wait_for_trigger = [
          {
            trigger = "mqtt";
            inherit topic;
            value_template = "{{ value_json.action | default('') }}";
            payload = button;
          }
        ];
        timeout.milliseconds = window;
        continue_on_timeout = true;
      };

      button = name: single: double: {
        alias = "${name} press";
        conditions = [
          {
            condition = "template";
            value_template = "{{ trigger.payload_json.action == '${name}' }}";
          }
        ];
        sequence =
          if double == [ ] then
            single
          else
            [
              (again name)
              {
                "if" = [
                  {
                    condition = "template";
                    value_template = "{{ wait.trigger is not none }}";
                  }
                ];
                "then" = double;
              }
              # A single press: nothing more, or its own action
            ]
            ++ (
              if single == [ ] then
                [ ]
              else
                [
                  {
                    "if" = [
                      {
                        condition = "template";
                        value_template = "{{ wait.trigger is none }}";
                      }
                    ];
                    "then" = single;
                  }
                ]
            );
      };
    in
    {
      id = "dafos_rodret_${id}";
      alias = "${alias} · Extras";
      description = "Double presses${
        if off != [ ] then " and the second off press" else ""
      } of the ${alias} RODRET; on/off and dimming are a direct Zigbee bind. Managed in Nix (modules/nixos/services/home-assistant/rodret.nix).";
      mode = "single";
      max_exceeded = "silent";
      triggers = [
        {
          trigger = "mqtt";
          inherit topic;
        }
      ];
      conditions = [
        {
          condition = "template";
          value_template = "{{ (trigger.payload_json.action | default('')) in ['on', 'off'] }}";
        }
      ];
      actions = [
        {
          choose = builtins.filter (b: b.sequence != [ ]) [
            (button "on" on onDouble)
            (button "off" off offDouble)
          ];
        }
      ];
    };
in
{
  automations = map automation switches;
}
