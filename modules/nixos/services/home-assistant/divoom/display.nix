# What the Divoom Timebox-Evo shows, in priority order:
#
# 1. A kitchen knob timer (esphome/minuteur.yaml):
#    finished -> "Minuteur N" scrolling until it is acknowledged;
#    running  -> the Divoom's own countdown tool, set to the earliest running
#                slot's time left. The Divoom counts down by itself; every
#                slot change (start, pause, knob turned, another slot ending
#                first) sets it again;
#    paused   -> "Pause mm:ss" when no slot is running.
# 2. The top household status (finished appliance, mail in the box), as its
#    icon in its colour (./icons.nix). A status that just came on first
#    scrolls its name. Hidden from 22:45 to 06:00.
# 3. The clock, in blue at full brightness.
#
# On top of that, script.divoom_cube_feedback shows what a remote just did as
# a short animation (./animations.nix) for a few seconds, then runs this
# display again to go back to whatever it showed. The veranda cube ("Véranda
# · Cube Controller", a UI blueprint automation) calls it first in each
# gesture, with `script.turn_on` so the gesture's own action does not wait.
#
# The countdown tool only takes minutes:seconds (devices/divoom.py drops the
# hours), so anything longer shows 99:59 until it gets under it, at the next
# slot change.
{ pkgs }:

let
  device = "divoom_timebox_evo_audio";

  statuses = [
    {
      key = "mail";
      entity = "input_boolean.outdoor_check_mailbox";
      name = "Courrier";
      icon = "mail";
      rgb = [
        229
        165
        10
      ];
    }
    {
      key = "household_trash";
      entity = "input_boolean.outdoor_household_trash";
      name = "Poubelle";
      icon = "trash";
      rgb = [
        26
        95
        180
      ];
    }
    {
      key = "recyclable_trash";
      entity = "input_boolean.outdoor_recyclable_trash";
      name = "Recyclage";
      icon = "recycling";
      rgb = [
        38
        162
        105
      ];
    }
    {
      key = "washing_machine";
      entity = "input_boolean.laundry_washing_machine_is_finished";
      name = "Lave-linge";
      icon = "washing_machine";
      rgb = [
        198
        70
        0
      ];
    }
    {
      key = "dryer";
      entity = "input_boolean.laundry_dryer_is_finished";
      name = "Sèche-linge";
      icon = "dryer";
      rgb = [
        198
        70
        0
      ];
    }
    {
      key = "dishwasher";
      entity = "input_boolean.kitchen_dishwasher_is_finished";
      name = "Lave-vaisselle";
      icon = "dishwasher";
      rgb = [
        255
        255
        255
      ];
    }
  ];

  icons = import ./icons.nix { inherit pkgs statuses; };
  animations = import ./animations.nix { inherit pkgs; };

  # One directory: the integration refuses a file whose realpath leaves it
  pixelart = pkgs.runCommand "divoom-pixelart" { } ''
    mkdir $out
    cp ${icons}/* ${animations.gifs}/* $out/
  '';

  # Slot 1 has no suffix (minuteur-automation.yaml)
  slots = [
    ""
    "_2"
    "_3"
  ];
  timerSensors = name: map (sfx: "sensor.minuteur_${name}${sfx}") slots;
  forSlots = "{% for sfx in ['', '_2', '_3'] %}";

  # The Divoom drops off Bluetooth now and then; the knob must keep working.
  divoom = action: data: {
    action = "divoom.${action}";
    data = {
      inherit device;
    }
    // data;
    continue_on_error = true;
  };

  # The clock, in blue at full brightness, whatever a status or timer left
  clockColour = [
    0
    0
    255
  ];

  # Seconds -> "mm:ss", capped at 99:59
  mmss = s: "{% set s = [${s}, 5999] | min %}{{ '%02d:%02d' % (s // 60, s % 60) }}";
in
{
  # The integration's media directory (`pixelart` in its config entry)
  tmpfiles = [ "L+ /var/lib/hass/pixelart - - - - ${pixelart}" ];

  scripts.divoom_cube_feedback = {
    alias = "Divoom · Cube feedback";
    description = "Shows a remote's action as an animation on the Divoom Timebox-Evo for a few seconds, then gives the display back to Divoom · Display. Managed in Nix (modules/nixos/services/home-assistant/divoom/display.nix).";
    icon = "mdi:cube-outline";
    # A new gesture replaces the animation and restarts the wait; the
    # integration sends one thing at a time, so uploads do not mix
    mode = "restart";
    fields = {
      animation = {
        description = "What the remote did";
        required = true;
        example = "light_on";
        selector.select.options = animations.names;
      };
      seconds = {
        description = "How long the animation stays up";
        default = 4;
        selector.number = {
          min = 1;
          max = 30;
        };
      };
    };
    sequence = [
      (divoom "image" { file = "{{ animation }}.gif"; })
      { delay.seconds = "{{ seconds | default(4) }}"; }
      {
        action = "automation.trigger";
        target.entity_id = "automation.divoom_display";
        data.skip_condition = true;
      }
    ];
  };

  automations = [
    {
      id = "dafos_divoom_display";
      alias = "Divoom · Display";
      description = "Shows the kitchen knob timers, then the top household status (icon in its colour), then the clock on the Divoom Timebox-Evo. Managed in Nix (modules/nixos/services/home-assistant/divoom/display.nix).";
      mode = "restart";
      variables = {
        statuses = map (s: {
          inherit (s)
            key
            entity
            name
            rgb
            ;
        }) statuses;
      };
      triggers = [
        {
          trigger = "state";
          entity_id = timerSensors "etat" ++ timerSensors "fin" ++ timerSensors "restant";
          # A knob waking up or reconnecting republishes what HA already has
          not_from = [
            "unavailable"
            "unknown"
          ];
          not_to = [
            "unavailable"
            "unknown"
          ];
          id = "timer";
        }
        {
          trigger = "state";
          entity_id = map (s: s.entity) statuses;
          to = [
            "on"
            "off"
          ];
          id = "status";
        }
        {
          trigger = "time";
          at = "22:45:00";
          id = "night";
        }
        {
          trigger = "time";
          at = "06:00:00";
          id = "morning";
        }
      ];
      actions = [
        # The knob publishes a slot's state, end and time left one after the
        # other; mode restart lets the last of them through.
        { delay = "00:00:01"; }
        {
          variables = {
            # Slot numbers (1..3) that rang and were not acknowledged
            finished = "{% set ns = namespace(n=[]) %}${forSlots}{% if is_state('sensor.minuteur_etat' ~ sfx, 'finished') %}{% set ns.n = ns.n + [loop.index] %}{% endif %}{% endfor %}{{ ns.n }}";
            # Seconds left on the earliest running slot, -1 if none runs
            running = "{% set ns = namespace(t=none) %}${forSlots}{% if is_state('sensor.minuteur_etat' ~ sfx, 'running') %}{% set d = states('sensor.minuteur_fin' ~ sfx) | as_datetime(none) %}{% if d is not none and (ns.t is none or d < ns.t) %}{% set ns.t = d %}{% endif %}{% endif %}{% endfor %}{{ -1 if ns.t is none else [(as_timestamp(ns.t) - as_timestamp(now())) | round(0, 'ceil') | int, 0] | max }}";
            # Seconds left on the shortest paused slot, -1 if none is paused
            paused = "{% set ns = namespace(s=none) %}${forSlots}{% if is_state('sensor.minuteur_etat' ~ sfx, 'paused') %}{% set r = states('sensor.minuteur_restant' ~ sfx) | int(0) %}{% if ns.s is none or r < ns.s %}{% set ns.s = r %}{% endif %}{% endif %}{% endfor %}{{ -1 if ns.s is none else ns.s }}";
          };
        }
        # Nix sorts attribute names, so variables that read each other get a
        # block each, in order.
        {
          variables.is_night = "{% set t = now().strftime('%H:%M:%S') %}{{ trigger.id != 'morning' and (t >= '22:45:00' or t < '06:00:00') }}";
        }
        {
          variables.top = "{{ none if is_night else (statuses | selectattr('entity', 'is_state', 'on') | list | first) | default(none) }}";
        }
        {
          variables.fresh = "{{ trigger.id == 'status' and trigger.to_state.state == 'on' and top is not none and top.entity == trigger.entity_id }}";
        }
        {
          choose = [
            {
              alias = "Timer finished";
              conditions = [ "{{ finished | count > 0 }}" ];
              sequence = [
                (divoom "text" {
                  text = "Minuteur {{ finished | join(' ') }}";
                  foreground_color = [
                    245
                    166
                    35
                  ];
                })
              ];
            }
            {
              alias = "Timer running";
              conditions = [ "{{ running > 0 }}" ];
              sequence = [
                (divoom "countdown" {
                  value = true;
                  countdown = mmss "running";
                })
              ];
            }
            {
              alias = "Timer paused";
              conditions = [ "{{ paused >= 0 }}" ];
              sequence = [
                (divoom "text" {
                  text = "Pause ${mmss "paused"}";
                  foreground_color = [
                    138
                    138
                    138
                  ];
                })
              ];
            }
            {
              alias = "Household status";
              conditions = [ "{{ top is not none }}" ];
              sequence = [
                {
                  "if" = [ "{{ fresh }}" ];
                  "then" = [
                    (divoom "text" {
                      text = "{{ top.name }}";
                      foreground_color = "{{ top.rgb }}";
                    })
                    { delay.seconds = 10; }
                  ];
                }
                (divoom "image" { file = "{{ top.key }}.png"; })
              ];
            }
          ];
          default = [
            (divoom "clock" {
              clock = 0;
              color = clockColour;
            })
            (divoom "brightness" { brightness = 100; })
          ];
        }
      ];
    }
    {
      # The Divoom keeps its own clock and knows nothing of time zones: it
      # stays an hour off after a summer/winter time change until it is sent
      # the time again. The change happens at 02:00 or 03:00 local, so at
      # 03:01 the offset two hours earlier differs only on those nights.
      id = "dafos_divoom_clock_sync";
      alias = "Divoom · Clock sync";
      description = "Sends Home Assistant's time to the Divoom Timebox-Evo after a summer/winter time change, and when Home Assistant starts. Managed in Nix (modules/nixos/services/home-assistant/divoom/display.nix).";
      mode = "single";
      triggers = [
        {
          trigger = "time";
          at = "03:01:00";
          id = "dst";
        }
        {
          trigger = "homeassistant";
          event = "start";
        }
      ];
      conditions = [
        "{{ trigger.id != 'dst' or (now() - timedelta(hours=2)).utcoffset() != now().utcoffset() }}"
      ];
      actions = [ (divoom "datetime" { }) ];
    }
  ];
}
