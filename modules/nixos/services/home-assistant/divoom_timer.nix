# The kitchen knob timer (esphome/minuteur.yaml) on the Divoom Timebox-Evo.
#
# Running  -> the Divoom's own countdown tool, set to the earliest running
#             slot's time left. The Divoom counts down by itself; every slot
#             change (start, pause, knob turned, another slot ending first)
#             sets it again.
# Paused   -> "Pause mm:ss" when no slot is running.
# Finished -> "Minuteur N" scrolling until it is acknowledged.
# Idle     -> back to the clock, only when coming from one of the above, so a
#             knob reconnecting or an HA restart leaves the display alone.
#
# The countdown tool only takes minutes:seconds (devices/divoom.py drops the
# hours), so anything longer shows 99:59 until it gets under it, at the next
# slot change.
_:

let
  device = "divoom_timebox_evo_audio";
  # Slot 1 has no suffix (minuteur-automation.yaml)
  slots = [
    ""
    "_2"
    "_3"
  ];
  sensors = name: map (sfx: "sensor.minuteur_${name}${sfx}") slots;
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

  # Seconds -> "mm:ss", capped at 99:59
  mmss = s: "{% set s = [${s}, 5999] | min %}{{ '%02d:%02d' % (s // 60, s % 60) }}";
in
{
  automations = [
    {
      id = "dafos_divoom_kitchen_timer";
      alias = "Cuisine · Minuteur sur la Divoom";
      description = "Affiche les minuteurs du bouton à molette sur la Divoom Timebox-Evo.";
      mode = "restart";
      triggers = [
        {
          trigger = "state";
          entity_id = sensors "etat" ++ sensors "fin" ++ sensors "restant";
          not_to = [
            "unavailable"
            "unknown"
          ];
        }
      ];
      actions = [
        # The device publishes a slot's state, end and time left one after
        # the other; mode restart lets the last of them through.
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
        {
          choose = [
            {
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
              conditions = [ "{{ running > 0 }}" ];
              sequence = [
                (divoom "countdown" {
                  value = true;
                  countdown = mmss "running";
                })
              ];
            }
            {
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
              conditions = [
                "{{ trigger.from_state is not none and trigger.from_state.state in ['running', 'paused', 'finished'] }}"
              ];
              sequence = [ (divoom "clock" { clock = 0; }) ];
            }
          ];
        }
      ];
    }
  ];
}
