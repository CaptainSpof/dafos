# Ink levels of the Canon TS9100 (192.168.0.60). Over IPP and SNMP it reports
# every level as -2 ("unknown"), so the ipp integration's ink sensors stay
# unknown. Its remote UI page builds the ink gauges from JS_MDL/model.js, which
# lists each tank as `inktank[i]=[colour, level, mark]`:
# - colour indexes inkCOL: Cyan, Black (BK), Photo Blue, Yellow, Black (PGBK),
#   Magenta;
# - level indexes Lv100, Lv090 … Lv000 (100 % to 0 % in 10 % steps), 11 = unknown;
# - mark: 0 fine, 1 low, 2 empty, 3 unknown.
# Read without credentials, once an hour.
{ lib }:

let
  inherit (lib) imap0;

  url = "http://192.168.0.60/JS_MDL/model.js";

  # inkCOL order on the printer
  tanks = [
    {
      id = "cyan";
      name = "Cyan";
    }
    {
      id = "black";
      name = "Black (BK)";
    }
    {
      id = "photo_blue";
      name = "Photo Blue";
    }
    {
      id = "yellow";
      name = "Yellow";
    }
    {
      id = "pigment_black";
      name = "Black (PGBK)";
    }
    {
      id = "magenta";
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
in
{
  rest = [
    {
      resource = url;
      scan_interval = 3600;
      timeout = 15;
      sensor =
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
              {{ ns.out | join(', ') if ns.out else 'OK' }}
            '';
          }
        ];
    }
  ];

  inherit tanks;
}
