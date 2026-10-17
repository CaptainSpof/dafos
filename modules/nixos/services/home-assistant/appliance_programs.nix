# Appliance programmes learned from their cycle lengths.
#
# A smart plug cannot tell the washer's programmes apart at the start: over the
# measured cycles a 75 min and a 232 min wash drew the same power for their
# first 30 min (heating from the 4th minute), and so did the dryer's 32 and
# 151 min programmes. A single learned length (the old moving average) was
# therefore wrong for every programme but the usual one.
#
# Instead, each appliance keeps a short list of the cycle lengths it actually
# runs, `[[minutes, cycles], ...]` in an input_text, and the expected length
# (input_number.<id>_expected_duration, read by the Maison dashboard's rings and
# by Household · Appliances for its progress notifications) is the shortest
# programme the running cycle has not yet outlasted by 10 %: a washer at 85 min
# moves from its 84 min programme to the 241 min one.
#
# Lengths are measured as Household · Appliances measures them: from
# input_datetime.<id>_started_at to the end of binary_sensor.<id>_active
# (sensors/binary_sensors.nix), so they include the detector's delay_off.
{ lib }:

let
  inherit (lib) concatMap listToAttrs map;

  appliances = [
    {
      id = "laundry_washing_machine";
      name = "Laundry · Washing Machine";
    }
    {
      id = "laundry_dryer";
      name = "Laundry · Dryer";
    }
    {
      id = "kitchen_dishwasher";
      name = "Kitchen · Dishwasher";
    }
  ];

  active = a: "binary_sensor.${a.id}_active";
  startedAt = a: "input_datetime.${a.id}_started_at";
  expected = a: "input_number.${a.id}_expected_duration";
  programs = a: "input_text.${a.id}_programs";

  # A cycle within 15 % of a known programme is that programme.
  tolerance = 0.15;
  # Moves to the next programme once the cycle outlasts this one by 10 %.
  overrun = 1.1;
  # Shorter cycles are aborted starts, not programmes.
  minCycle = 15;
  # Programmes kept per appliance (the most used).
  keep = 5;

  # Jinja: the appliance's programme list, [] when empty or unreadable
  readPrograms = a: ''
    {% set raw = states('${programs a}') %}
    {% set progs = raw | from_json if raw.startswith('[') else [] %}
  '';
  minutesSinceStart =
    a:
    "((now().timestamp() - as_timestamp(states('${startedAt a}'), now().timestamp())) / 60) | round(0) | int";

  # Jinja statements setting `target`, the expected length for a cycle
  # `elapsed` minutes in
  setTarget = a: elapsed: ''
    ${readPrograms a}
    {% set lengths = progs | map(attribute='0') | sort | list %}
    {% set fit = lengths | select('ge', (${elapsed}) / ${toString overrun}) | list %}
    {% set target = (fit | first) if fit else (lengths | last if lengths else states('${expected a}') | int(60)) %}
  '';
  pick = a: elapsed: "${setTarget a elapsed}{{ target }}";

  setExpected = a: value: {
    action = "input_number.set_value";
    target.entity_id = expected a;
    data.value = value;
  };
in
{
  input_text = listToAttrs (
    map (a: {
      name = "${a.id}_programs";
      value = {
        name = "${a.name} programmes";
        icon = "mdi:format-list-numbered";
        max = 255;
        # No `initial`: it would forget the learned list on every restart.
      };
    }) appliances
  );

  automations = [
    {
      id = "dafos_household_appliance_programs";
      alias = "Household · Appliance Programmes";
      description = "Learns each appliance's programme lengths from its cycles and sets the expected cycle length to the shortest programme the running cycle has not outlasted. Managed in Nix (modules/nixos/services/home-assistant/appliance_programs.nix).";
      mode = "queued";
      triggers =
        concatMap (a: [
          {
            trigger = "state";
            entity_id = active a;
            from = "on";
            to = "off";
            id = "end-${a.id}";
          }
        ]) appliances
        ++ [
          {
            trigger = "time_pattern";
            minutes = "/1";
            id = "tick";
          }
          {
            trigger = "homeassistant";
            event = "start";
            id = "tick";
          }
        ];
      actions = [
        {
          choose = map (a: {
            alias = "${a.name}: cycle over, learn its length";
            conditions = [
              {
                condition = "trigger";
                id = "end-${a.id}";
              }
            ];
            sequence = [
              {
                variables.duration = "{{ ${minutesSinceStart a} }}";
              }
              {
                "if" = [
                  {
                    condition = "template";
                    value_template = "{{ ${toString minCycle} <= duration <= 480 }}";
                  }
                ];
                "then" = [
                  {
                    action = "input_text.set_value";
                    target.entity_id = programs a;
                    data.value = ''
                      ${readPrograms a}
                      {% set ns = namespace(out=[], hit=false) %}
                      {% for p in progs %}
                        {% if not ns.hit and (p[0] - duration) | abs <= p[0] * ${toString tolerance} %}
                          {% set c = [p[1], 9] | min %}
                          {% set ns.out = ns.out + [[((p[0] * c + duration) / (c + 1)) | round(0) | int, p[1] + 1]] %}
                          {% set ns.hit = true %}
                        {% else %}
                          {% set ns.out = ns.out + [p] %}
                        {% endif %}
                      {% endfor %}
                      {# first: a new programme wins ties for the last places #}
                      {% if not ns.hit %}{% set ns.out = [[duration, 1]] + ns.out %}{% endif %}
                      {{ (ns.out | sort(attribute='1', reverse=true))[:${toString keep}] | sort(attribute='0') | to_json }}
                    '';
                  }
                ];
              }
              # After Household · Appliances, which still folds the cycle into
              # its moving average at the same moment: the next cycle starts
              # from the shortest programme.
              { delay.seconds = 15; }
              (setExpected a (pick a "0"))
            ];
          }) appliances;
        }
        {
          alias = "Running cycles: expect the shortest programme not yet outlasted";
          "if" = [
            {
              condition = "trigger";
              id = "tick";
            }
          ];
          "then" = map (a: {
            "if" = [
              {
                condition = "state";
                entity_id = active a;
                state = "on";
              }
              {
                condition = "template";
                value_template = "${setTarget a (minutesSinceStart a)}{{ target | int != states('${expected a}') | int(0) }}";
              }
            ];
            "then" = [ (setExpected a (pick a (minutesSinceStart a))) ];
          }) appliances;
        }
      ];
    }
  ];
}
