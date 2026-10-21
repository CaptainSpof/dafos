# Ink levels of the Canon TS9100 (192.168.0.60). Over IPP and SNMP it reports
# every level as -2 ("unknown"), so the ipp integration's ink sensors stay
# unknown. Its remote UI page builds the ink gauges from JS_MDL/model.js, which
# lists each tank as `inktank[i]=[colour, level, mark]`:
# - colour indexes inkCOL: Cyan, Black (BK), Photo Blue, Yellow, Black (PGBK),
#   Magenta;
# - level indexes Lv100, Lv090 … Lv000 (100 % to 0 % in 10 % steps), 11 = unknown;
# - mark: 0 fine, 1 low, 2 empty, 3 unknown.
# Read without credentials, once an hour.
#
# Read with curl, not the rest integration: asleep, the printer answers the
# first request with a 404 ("A specification file is not found") and only
# serves the page a few seconds later. With rest, an HA start during the
# printer's sleep never created the sensors (PlatformNotReady, retried only
# against the next hourly read, itself a 404 again). curl retries for ~30 s
# and passes on only the tank lines.
{ lib, pkgs }:

let
  inherit (lib) imap0 map;

  url = "http://192.168.0.60/JS_MDL/model.js";
  # `inktank[0]=[0,6,0] inktank[1]=[1,1,0] ...`, empty when the printer
  # cannot be read (switched off): the sensors then read unknown.
  command = lib.concatStringsSep " " [
    "${pkgs.curl}/bin/curl -sf -m 10 --retry 6 --retry-delay 5 --retry-all-errors ${url}"
    "| ${pkgs.gnugrep}/bin/grep -o 'inktank\\[[0-9]*\\]=\\[[0-9,]*\\]'"
    "| ${pkgs.coreutils}/bin/tr '\\n' ' '"
  ];

  # inkCOL order on the printer
  tanks = [
    {
      id = "cyan";
      label = "Cyan";
      name = "Cyan";
    }
    {
      id = "black";
      label = "Noir";
      name = "Black (BK)";
    }
    {
      id = "photo_blue";
      label = "Bleu photo";
      name = "Photo Blue";
    }
    {
      id = "yellow";
      label = "Jaune";
      name = "Yellow";
    }
    {
      id = "pigment_black";
      label = "Noir pigment";
      name = "Black (PGBK)";
    }
    {
      id = "magenta";
      label = "Magenta";
      name = "Magenta";
    }
  ];

  # The [level, mark] pair of the tank whose colour index is `colour`, or none
  tank = colour: ''
    {% set ns = namespace(t=none) %}
    {% for c, l, m in value | regex_findall('inktank\\[\\d+\\]=\\[(\\d+),(\\d+),(\\d+)\\]') %}
      {% if c | int == ${toString colour} %}{% set ns.t = [l | int, m | int] %}{% endif %}
    {% endfor %}
  '';
  # A tank counts as low at 20 % or less (two gauge steps before empty), or as
  # soon as the printer itself marks one low or empty.
  lowLevel = 20;
  # Back to fine once every tank is at 30 % or more: a cartridge was replaced.
  fineLevel = 30;

  sensorOf = t: "sensor.printer_ink_${t.id}";
  alert = "sensor.printer_ink_alert";

  # Jinja: "Jaune 20 %, Cyan 10 %" for the tanks at or under lowLevel
  lowList = ''
    {% set ns = namespace(out=[]) %}
    {% for e, n in ${
      builtins.toJSON (
        map (t: [
          (sensorOf t)
          t.label
        ]) tanks
      )
    } %}
      {% set v = states(e) | float(none) %}
      {% if v is not none and v <= ${toString lowLevel} %}{% set ns.out = ns.out + [n ~ ' ' ~ (v | int) ~ ' %'] %}{% endif %}
    {% endfor %}
  '';
in
{
  # One command per sensor: command_line has no shared resource as rest has.
  command_line =
    map
      (sensor: {
        sensor = sensor // {
          inherit command;
          scan_interval = 3600;
          command_timeout = 90;
          # A sleeping or unreachable printer leaves `value` without the ink
          # report; rendering `none` then gives the string "None", which made
          # HA refuse to add the numeric sensors at all (2026-10-21).
          availability = "{{ value is defined and 'inktank' in (value | string) }}";
        };
      })
      (
        imap0 (colour: t: {
          name = "Printer ink ${t.id}";
          unique_id = "dafos.sensor.printer_ink_${t.id}";
          icon = "mdi:water";
          unit_of_measurement = "%";
          state_class = "measurement";
          value_template = ''
            ${tank colour}
            {{ (100 - 10 * ns.t[0]) if ns.t is not none and ns.t[0] <= 10 else none }}
          '';
        }) tanks
        ++ [
          {
            # "OK", or the tanks the printer marks low or empty
            name = "Printer ink alert";
            unique_id = "dafos.sensor.printer_ink_alert";
            icon = "mdi:water-alert";
            value_template = ''
              {% set names = ${builtins.toJSON (map (t: t.name) tanks)} %}
              {% set ns = namespace(out=[]) %}
              {% for c, l, m in value | regex_findall('inktank\\[\\d+\\]=\\[(\\d+),(\\d+),(\\d+)\\]') %}
                {% if m | int in [1, 2] and c | int < names | count %}
                  {% set ns.out = ns.out + [names[c | int] ~ (' vide' if m | int == 2 else ' bas')] %}
                {% endif %}
              {% endfor %}
              {% if value | regex_findall('inktank') | count == 0 %}{{ none }}
              {% else %}{{ ns.out | join(', ') if ns.out else 'OK' }}{% endif %}
            '';
          }
        ]
      );

  automations = [
    {
      id = "dafos_printer_ink_low";
      alias = "Printer · Ink Low";
      description = "Notifies when a Canon TS9100 tank drops to ${toString lowLevel} % or the printer marks one low or empty; clears once every tank is back at ${toString fineLevel} % or more. Managed in Nix (modules/nixos/services/home-assistant/printer_ink.nix).";
      mode = "queued";
      triggers =
        map (t: {
          trigger = "numeric_state";
          entity_id = sensorOf t;
          below = lowLevel + 1;
          id = "low";
        }) tanks
        ++ [
          {
            trigger = "state";
            entity_id = alert;
            not_to = [
              "OK"
              "unknown"
              "unavailable"
            ];
            id = "low";
          }
          {
            trigger = "state";
            entity_id = map sensorOf tanks;
            id = "change";
          }
        ];
      actions = [
        {
          choose = [
            {
              alias = "A tank is low: notify, listing the low tanks";
              conditions = [
                {
                  condition = "trigger";
                  id = "low";
                }
              ];
              sequence = [
                {
                  action = "notify.mobile_app_dafphone";
                  data = {
                    title = "Encre faible sur l'imprimante";
                    message = ''
                      ${lowList}
                      {% set marked = states('${alert}') %}
                      {{ (ns.out | join(', ')) if ns.out else marked }}{{ ' (imprimante : ' ~ marked ~ ')' if ns.out and marked not in ['OK', 'unknown', 'unavailable'] else ''' }}
                    '';
                    data = {
                      tag = "printer_ink";
                      group = "Tâches";
                      channel = "household";
                      notification_icon = "mdi:printer-alert";
                    };
                  };
                }
              ];
            }
            {
              alias = "Every tank fine again (cartridge replaced): clear";
              conditions = [
                {
                  condition = "trigger";
                  id = "change";
                }
                {
                  condition = "template";
                  value_template = "{{ ${builtins.toJSON (map sensorOf tanks)} | map('states') | map('float', 0) | min >= ${toString fineLevel} and is_state('${alert}', 'OK') }}";
                }
              ];
              sequence = [
                {
                  action = "notify.mobile_app_dafphone";
                  data = {
                    message = "clear_notification";
                    data.tag = "printer_ink";
                  };
                }
              ];
            }
          ];
        }
      ];
    }
  ];

  inherit tanks;
}
