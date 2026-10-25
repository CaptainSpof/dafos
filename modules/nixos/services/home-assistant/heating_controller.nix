# Global · Heating Controller, moved from the UI to Nix on 2026-10-23 with its
# behaviour unchanged (the generated config was checked equal to the UI one).
#
# Single owner of the heating: radiator valves, pellet stove, Netatmo
# away/schedule and boiler boosts. State-based: every trigger recomputes each
# room's target from the room table below, so a restart or a missed trigger
# self-heals. Season = binary_sensor.global_is_cold_season (select.dafnanterre
# == Hiver). Stove is driven through the Broadlink IR remote
# (remote.living_room_universal_remote, device poele, command power, long
# press = 15 repeats), only on events (06:00 at the earliest, or one hour
# before a dafphone alarm set between 06:00 and 10:00, back home, season →
# Hiver; 22:45, heating away, nobody home for 1 h, heating_stove_off event
# from the bedroom NFC tag; input_button.heating_stove_on_off on the
# dashboard: off if burning, else on), so a manual change sticks. Automatic starts only happen below 19
# °C in the living room (sensor.living_room_current_temperature, Netatmo);
# once it has burned 1 h, the stove is stopped when the living room has been ≥
# 20 °C for 10 min (stove-warm). During the day it is relit when the living
# room has been below 18.5 °C for 10 min (stove-cold), until 21:00; no
# automatic start after 21:00 (too late in the evening), manual starts still
# work. To save the idle draw the plug is cut once the stove has been off and
# cool for 15 min (or powered 20 min without starting), and switched back on 3
# min before an IR start; it is never cut while burning. Out of season valves
# sit at 7°C. The heating pop-up's "Mode chauffage" (input_select.heating_mode)
# has three states: Auto, Absent (set by the "Heating Off" notification
# button) and Retour imminent. Absent puts every valve at its eco target and
# Netatmo on away. So does Auto once nobody has been home for 1 h, and it also
# stops the stove; Netatmo goes back to its schedule when someone is back.
# Retour imminent overrides away to preheat: Netatmo on its schedule, every
# room heated as if occupied, stove left alone. It goes back to Auto once
# someone is home, or after 3 h. Boiler boost:
# a valve has been heating at least 0.5 °C below its target for 10 min while
# the Netatmo is idle -> Netatmo +2°C for 30 min, at most once an hour. It
# superseded the per-room Radiator Controllers, Living Room · Stove Controller
# and Global · Notify When Thermostats Demand Heating (deleted 2026-10-20).
#
# Room table: valve, presence entities, comfort windows (input_datetime ids or
# "HH:MM", wrapping past midnight; an optional third element overrides comfort
# for that window, first match wins), comfort/eco temperatures. Change heating
# behaviour here, not with per-room automations.
_:

let
  rooms = [
    {
      name = "Bedroom";
      climate = "climate.bedroom_radiator_thermostat";
      presence = [
        "person.cedric_da_fonseca"
      ];
      windows = [
        [
          "input_datetime.early_evening"
          "input_datetime.night"
        ]
        [
          "input_datetime.night"
          "input_datetime.early_morning"
          17
        ]
        [
          "input_datetime.early_morning"
          "input_datetime.late_morning"
        ]
      ];
      comfort = 18;
      eco = 16;
    }
    {
      name = "Bathroom";
      climate = "climate.bathroom_radiator";
      presence = [
        "person.cedric_da_fonseca"
      ];
      windows = [
        [
          "input_datetime.early_morning"
          "input_datetime.noon"
        ]
      ];
      comfort = 18;
      eco = 12;
    }
    {
      name = "Kitchen";
      climate = "climate.kitchen_radiator_thermostat";
      presence = [
        "binary_sensor.global_maybe_home_occupied"
      ];
      windows = [
        [
          "input_datetime.early_morning"
          "input_datetime.early_afternoon"
        ]
        [
          "input_datetime.early_evening"
          "input_datetime.late_evening"
        ]
      ];
      comfort = 18;
      eco = 12;
    }
    {
      name = "Véranda";
      climate = "climate.veranda_radiator";
      presence = [
        "binary_sensor.global_maybe_home_occupied"
      ];
      windows = [
        [
          "input_datetime.early_morning"
          "input_datetime.early_afternoon"
        ]
        [
          "input_datetime.early_evening"
          "input_datetime.late_evening"
        ]
      ];
      comfort = 18;
      eco = 12;
    }
    {
      name = "Parents Bedroom";
      climate = "climate.parents_bedroom_radiator";
      presence = [
        "person.joaquim_da_fonseca"
        "person.myriam_da_fonseca"
        "person.johan"
      ];
      windows = [
        [
          "06:00"
          "09:30"
        ]
        [
          "19:00"
          "22:00"
        ]
      ];
      arrival_comfort = "person.johan";
      comfort = 18;
      eco = 15;
    }
    {
      name = "Desk";
      climate = "climate.desk_radiator_thermostat";
      presence = [
        "device_tracker.dafbox"
      ];
      windows = [
        [
          "input_datetime.early_morning"
          "input_datetime.night"
        ]
      ];
      comfort = 19;
      eco = 15;
    }
  ];

  valves = map (r: r.climate) rooms;

  # A valve wants heat when it is heating and its room is at least 0.5 °C below
  # the valve's target: TRVs report `heating` 0.1 °C short, which alone would
  # fire the whole Netatmo loop for one room all night.
  wantsHeat =
    c:
    "(is_state_attr(${c}, 'hvac_action', 'heating') and state_attr(${c}, 'temperature') | float(0) - state_attr(${c}, 'current_temperature') | float(99) >= 0.5)";
  valvesWantingHeat = "{% set ns = namespace(n=0) %}{% for c in ${builtins.toJSON valves} %}{% if ${wantsHeat "c"} %}{% set ns.n = ns.n + 1 %}{% endif %}{% endfor %}";
in
{
  input_select.heating_mode = {
    name = "Heating · Mode";
    icon = "mdi:home-switch-outline";
    options = [
      "Auto"
      "Absent"
      "Retour imminent"
    ];
  };

  # Hours somebody was home over the last hour; 0 means the house has been
  # empty for an hour. Entity id: sensor.heating_home_occupied_last_hour.
  platformSensors = [
    {
      platform = "history_stats";
      name = "Heating home occupied last hour";
      unique_id = "dafos.sensor.heating_home_occupied_last_hour";
      entity_id = "binary_sensor.global_home_is_occupied";
      state = "on";
      type = "time";
      start = "{{ now() - timedelta(hours=1) }}";
      end = "{{ now() }}";
    }
  ];

  automations = [
    {
      id = "dafos_heating_controller";
      alias = "Global · Heating Controller";
      description = "Single owner of the heating: radiator valves, pellet stove, Netatmo away/schedule and boiler boosts. Managed in Nix (modules/nixos/services/home-assistant/heating_controller.nix), where the full behaviour is documented.";
      triggers = [
        {
          trigger = "time";
          id = "slot";
          at = [
            "input_datetime.early_morning"
            "input_datetime.late_morning"
            "input_datetime.noon"
            "input_datetime.early_afternoon"
            "input_datetime.early_evening"
            "input_datetime.late_evening"
            "input_datetime.night"
            "06:00:00"
            "09:30:00"
            "19:00:00"
            "22:00:00"
            "22:45:00"
          ];
        }
        {
          trigger = "state";
          id = "presence";
          entity_id = [
            "person.cedric_da_fonseca"
            "person.joaquim_da_fonseca"
            "person.myriam_da_fonseca"
            "person.johan"
            "device_tracker.dafbox"
            "binary_sensor.global_maybe_home_occupied"
            "binary_sensor.global_home_is_occupied"
          ];
          not_to = [
            "unavailable"
            "unknown"
          ];
        }
        {
          trigger = "state";
          id = "season";
          entity_id = "binary_sensor.global_is_cold_season";
          not_to = [
            "unavailable"
            "unknown"
          ];
        }
        {
          trigger = "state";
          id = "mode";
          entity_id = "input_select.heating_mode";
          not_to = [
            "unavailable"
            "unknown"
          ];
        }
        {
          alias = "Nobody has been home for an hour (read from the recorder, so a restart does not reset the count)";
          trigger = "template";
          id = "house-empty";
          value_template = "{{ is_state('binary_sensor.global_home_is_occupied', 'off') and states('sensor.heating_home_occupied_last_hour') | float(1) < 0.02 }}";
        }
        {
          trigger = "state";
          id = "return-soon-timeout";
          entity_id = "input_select.heating_mode";
          to = "Retour imminent";
          for = {
            hours = 3;
          };
        }
        {
          trigger = "state";
          id = "valve-back";
          entity_id = valves;
          from = "unavailable";
        }
        {
          trigger = "event";
          id = "reapply";
          event_type = "heating_reapply";
        }
        {
          trigger = "homeassistant";
          id = "start";
          event = "start";
        }
        {
          trigger = "template";
          id = "boost";
          value_template = ''
            ${valvesWantingHeat}
            {{ is_state('binary_sensor.global_is_cold_season', 'on')
               and state_attr('climate.sejour', 'hvac_action') == 'idle'
               and ns.n > 0 }}'';
          for = {
            minutes = 10;
          };
        }
        {
          trigger = "time_pattern";
          id = "boost";
          minutes = "/15";
        }
        {
          trigger = "event";
          id = "stove-off";
          event_type = "heating_stove_off";
        }
        {
          trigger = "state";
          id = "stove-idle";
          entity_id = "binary_sensor.living_room_stove_is_maybe_burning";
          to = "off";
          for = {
            minutes = 15;
          };
        }
        {
          trigger = "state";
          id = "stove-idle";
          entity_id = "switch.living_room_stove_switch";
          to = "on";
          for = {
            minutes = 20;
          };
        }
        {
          trigger = "event";
          id = "stove-on";
          event_type = "heating_stove_on";
        }
        {
          trigger = "state";
          id = "stove-toggle";
          entity_id = "input_button.heating_stove_on_off";
          not_to = [
            "unavailable"
          ];
        }
        {
          trigger = "template";
          id = "stove-warm";
          alias = "Living room 1 °C above the Netatmo target (at most 20 °C) for 10 min, and the stove has burned for at least 1 h; the veranda stands in while Netatmo is offline";
          value_template = ''
            {% set last = states('input_datetime.heating_last_stove_command') | as_datetime(none) %}
            {% set temp = (states('sensor.living_room_current_temperature') | float(none) if has_value('sensor.living_room_current_temperature') else states('sensor.veranda_temperature_sensor_temperature') | float(none)) %}
            {% set target = state_attr('climate.sejour', 'temperature') | float(19) %}
            {{ temp is not none and temp >= [target + 1, 20] | min
               and is_state('binary_sensor.living_room_stove_is_maybe_burning', 'on')
               and (last is none or now() - last | as_local > timedelta(hours=1)) }}'';
          for = {
            minutes = 10;
          };
        }
        {
          trigger = "template";
          id = "stove-cold";
          alias = "Living room cooled below 18.5 °C for 10 min, stove off, last command > 45 min ago (re-arms by itself once the cooldown has passed)";
          value_template = ''
            {% set last = states('input_datetime.heating_last_stove_command') | as_datetime(none) %}
            {{ (states('sensor.living_room_current_temperature') | float(none) if has_value('sensor.living_room_current_temperature') else states('sensor.veranda_temperature_sensor_temperature') | float(none)) | float(99) < 18.5
               and is_state('binary_sensor.living_room_stove_is_maybe_burning', 'off')
               and (last is none or now() - last | as_local > timedelta(minutes=45)) }}'';
          for = {
            minutes = 10;
          };
        }
        {
          trigger = "state";
          id = "stove-state";
          entity_id = "binary_sensor.living_room_stove_is_maybe_burning";
          not_from = [
            "unavailable"
            "unknown"
          ];
          not_to = [
            "unavailable"
            "unknown"
          ];
        }
        {
          trigger = "template";
          id = "stove-morning";
          alias = "Morning stove start: 06:00, or one hour before a dafphone alarm set between 06:00 and 10:00";
          value_template = "{% set a = states('sensor.dafphone_next_alarm') | as_datetime(none) %}{% set a = a | as_local if a is not none else none %}{% set al = a.strftime('%H:%M') if a is not none and a.date() == now().date() else '' %}{% set start = ['06:00', (a - timedelta(hours=1)).strftime('%H:%M')] | max if '06:00' <= al <= '10:00' else '06:00' %}{{ now().strftime(\"%H:%M\") == start }}";
        }
      ];
      conditions = [ ];
      actions = [
        {
          alias = "After a restart, wait for the occupancy history before deciding anything (until then the house would count as occupied)";
          "if" = [
            {
              condition = "trigger";
              id = "start";
            }
          ];
          "then" = [
            {
              wait_template = "{{ has_value('sensor.heating_home_occupied_last_hour') }}";
              timeout = {
                minutes = 3;
              };
              continue_on_timeout = true;
            }
          ];
        }
        {
          alias = "Netatmo follows away: whenever it disagrees with the controller (a restart or a missed trigger must not leave the boiler on the schedule in an empty house). Only the away preset is touched, a manual Netatmo setting is left alone";
          "if" = [
            {
              condition = "template";
              value_template = "{{ trigger.id in ['mode', 'house-empty'] or (away and not is_state_attr('climate.sejour', 'preset_mode', 'away')) or (not away and is_state_attr('climate.sejour', 'preset_mode', 'away')) }}";
            }
          ];
          "then" = [
            {
              action = "climate.set_preset_mode";
              continue_on_error = true;
              target = {
                entity_id = "climate.sejour";
              };
              data = {
                preset_mode = "{{ 'away' if away else 'schedule' }}";
              };
            }
          ];
        }
        {
          choose = [
            {
              alias = "Stove changed state: its warnings (pas démarré / pas éteint) are no longer current";
              conditions = [
                {
                  condition = "trigger";
                  id = "stove-state";
                }
              ];
              sequence = [
                {
                  action = "notify.mobile_app_dafphone";
                  data = {
                    message = "clear_notification";
                    data = {
                      tag = "heating_stove";
                    };
                  };
                }
                {
                  stop = "Stove warning cleared";
                }
              ];
            }
            {
              alias = "Boiler boost — a valve wants heat but the boiler is idle";
              conditions = [
                {
                  condition = "trigger";
                  id = "boost";
                }
                {
                  alias = "Still true now (the time_pattern retry does not imply it)";
                  condition = "template";
                  value_template = ''
                    ${valvesWantingHeat}
                    {{ season and not away
                       and state_attr('climate.sejour', 'hvac_action') == 'idle'
                       and state_attr('climate.sejour', 'preset_mode') == 'schedule'
                       and ns.n > 0 }}'';
                }
                {
                  alias = "At most one boost per hour";
                  condition = "template";
                  value_template = "{% set last = states('input_datetime.heating_last_boiler_boost') | as_datetime(none) %} {{ last is none or now() - last | as_local > timedelta(hours=1) }}";
                }
              ];
              sequence = [
                {
                  variables = {
                    cold_rooms = ''
                      {% set ns = namespace(n=[]) %}{% for r in rooms %}{% set c = r.climate %}{% if ${wantsHeat "c"} %}{% set ns.n = ns.n + [r.name] %}{% endif %}{% endfor %}
                      {{ ns.n }}'';
                    boost_temp = "{{ [ (state_attr('climate.sejour', 'current_temperature') | float(18)) + 2, 30 ] | min }}";
                  };
                }
                {
                  action = "netatmo.set_temperature_with_time_period";
                  target = {
                    entity_id = "climate.sejour";
                  };
                  data = {
                    target_temperature = "{{ boost_temp }}";
                    time_period = "00:30:00";
                  };
                }
                {
                  action = "input_datetime.set_datetime";
                  target = {
                    entity_id = "input_datetime.heating_last_boiler_boost";
                  };
                  data = {
                    datetime = "{{ now().strftime('%Y-%m-%d %H:%M:%S') }}";
                  };
                }
                {
                  action = "notify.mobile_app_dafphone";
                  data = {
                    title = "🔥 Chaudière relancée 30 min";
                    message = "{{ cold_rooms | join(', ') }} {{ 'demandent' if cold_rooms | count > 1 else 'demande' }} de la chaleur (Séjour → {{ boost_temp }}°C).";
                    data = {
                      tag = "heating_boost";
                      channel = "Chauffage";
                      notification_icon = "mdi:fire";
                      group = "Chauffage";
                      timeout = 1800;
                    };
                  };
                }
              ];
            }
            {
              alias = "Stove idle — cut the plug's standby draw once the stove is off and cool";
              conditions = [
                {
                  condition = "trigger";
                  id = "stove-idle";
                }
                {
                  condition = "state";
                  entity_id = "switch.living_room_stove_switch";
                  state = "on";
                }
                {
                  condition = "state";
                  entity_id = "binary_sensor.living_room_stove_is_maybe_burning";
                  state = "off";
                }
                {
                  condition = "template";
                  value_template = ''
                    {% set last = states('input_datetime.heating_last_stove_command') | as_datetime(none) %} {{ states('sensor.living_room_stove_power') | float(0) < 30
                       and (last is none or now() - last | as_local > timedelta(minutes=20)) }}'';
                }
              ];
              sequence = [
                {
                  action = "switch.turn_off";
                  target = {
                    entity_id = "switch.living_room_stove_switch";
                  };
                }
              ];
            }
            {
              alias = "Return soon, nobody back after 3 h: back to Auto (that change re-runs the controller, which goes back to away)";
              conditions = [
                {
                  condition = "trigger";
                  id = "return-soon-timeout";
                }
              ];
              sequence = [
                {
                  action = "input_select.select_option";
                  target = {
                    entity_id = "input_select.heating_mode";
                  };
                  data = {
                    option = "Auto";
                  };
                }
                {
                  stop = "Return soon expired";
                }
              ];
            }
            {
              alias = "Boost / stove-idle checks with nothing to do: stop here, do not fall through to the room recompute (it would overwrite manual valve tweaks every 15 min)";
              conditions = [
                {
                  condition = "trigger";
                  id = [
                    "boost"
                    "stove-idle"
                  ];
                }
              ];
              sequence = [
                {
                  stop = "Nothing to do";
                }
              ];
            }
          ];
          default = [
            {
              alias = "Someone is home: return soon has done its job";
              "if" = [
                {
                  condition = "state";
                  entity_id = "input_select.heating_mode";
                  state = "Retour imminent";
                }
                {
                  condition = "state";
                  entity_id = "binary_sensor.global_home_is_occupied";
                  state = "on";
                }
              ];
              "then" = [
                {
                  action = "input_select.select_option";
                  target = {
                    entity_id = "input_select.heating_mode";
                  };
                  data = {
                    option = "Auto";
                  };
                }
              ];
            }
            {
              alias = "Radiator valves";
              repeat = {
                for_each = "{{ rooms }}";
                sequence = [
                  {
                    variables = {
                      hm = "{{ now().strftime('%H:%M') }}";
                      window_temp = ''
                        {% set ns = namespace(t=0) %} {% for w in repeat.item.windows %}
                          {% set s = states(w[0])[:5] if w[0].startswith('input_datetime.') else w[0] %}
                          {% set e = states(w[1])[:5] if w[1].startswith('input_datetime.') else w[1] %}
                          {% if ns.t == 0 and ((s <= e and s <= hm < e) or (s > e and (hm >= s or hm < e))) %}{% set ns.t = w[2] if w | count > 2 else repeat.item.comfort %}{% endif %}
                        {% endfor %} {{ ns.t }}'';
                      present = "{{ returning or repeat.item.presence | select('is_state', ['home', 'on']) | list | count > 0 }}";
                      arrival = ''
                        {% set p = repeat.item.get('arrival_comfort') %} {{ p is not none and is_state(p, 'home')
                           and now() - states[p].last_changed < timedelta(hours=3) }}'';
                      target = "{% if not season %}{{ off_season_temp }} {% elif away %}{{ repeat.item.eco }} {% elif present | bool and window_temp | float(0) > 0 %}{{ window_temp }} {% elif arrival | bool %}{{ repeat.item.comfort }} {% else %}{{ repeat.item.eco }}{% endif %}";
                    };
                  }
                  {
                    "if" = [
                      {
                        condition = "template";
                        value_template = ''
                          {{ states(repeat.item.climate) not in ['unavailable', 'unknown']
                             and (is_state(repeat.item.climate, 'off')
                                  or state_attr(repeat.item.climate, 'temperature') | float(-1) != target | float) }}'';
                      }
                    ];
                    "then" = [
                      {
                        action = "climate.set_temperature";
                        continue_on_error = true;
                        target = {
                          entity_id = "{{ repeat.item.climate }}";
                        };
                        data = {
                          hvac_mode = "heat";
                          temperature = "{{ target | float }}";
                        };
                      }
                    ];
                  }
                ];
              };
            }
            {
              alias = "Pellet stove — what this trigger asks for";
              variables = {
                hm = "{{ now().strftime('%H:%M') }}";
                stove = ''
                  {% set t = trigger.id %} {% if t == 'stove-off' or t == 'stove-warm' or (t == 'stove-toggle' and is_state('binary_sensor.living_room_stove_is_maybe_burning', 'on') and is_state('switch.living_room_stove_switch', 'on')) or (t == 'slot' and hm == '22:45') or (t == 'mode' and away) or (t == 'house-empty' and away) %}off {% elif t == 'stove-on' or (t == 'stove-toggle' and not (is_state('binary_sensor.living_room_stove_is_maybe_burning', 'on') and is_state('switch.living_room_stove_switch', 'on'))) %}on
                  {% elif season and not away and stove_start <= hm < '21:00'
                       and is_state('binary_sensor.global_home_is_occupied', 'on')
                       and (states('sensor.living_room_current_temperature') | float(none) if has_value('sensor.living_room_current_temperature') else states('sensor.veranda_temperature_sensor_temperature') | float(none)) | float(99) < 19
                       and (t == 'stove-morning'
                            or (t == 'mode' and not away)
                            or (t == 'season' and season)
                            or t == 'stove-cold'
                            or (t == 'presence' and trigger.entity_id == 'binary_sensor.global_home_is_occupied'
                                and trigger.to_state.state == 'on')) %}on
                  {% else %}keep{% endif %}'';
                stove_cooldown_ok = "{% set last = states('input_datetime.heating_last_stove_command') | as_datetime(none) %} {{ last is none or now() - last | as_local > timedelta(minutes=45) }}";
                stove_manual_off_ok = "{% set last = states('input_datetime.heating_last_stove_command') | as_datetime(none) %} {% set lit = states('sensor.heating_stove_last_start') | as_datetime(none) %} {{ trigger.id in ['stove-off', 'stove-toggle'] and last is not none and lit is not none and lit >= (last | as_local) - timedelta(minutes=1) }}";
              };
            }
            {
              alias = "Pellet stove — driven through its IR remote (the on/off key needs a long press: 15 repeats, no delay). The same key toggles, so it is only sent when binary_sensor.living_room_stove_is_maybe_burning (plug >30 W in the last 10 min) says the stove is in the other state, and at most every 45 min so a stove that is still shutting down is never relit. The plug is only cut once the stove is off and cooled (idle draw), never while it burns.";
              choose = [
                {
                  conditions = [
                    {
                      condition = "template";
                      value_template = "{{ stove | trim == 'off' }}";
                    }
                  ];
                  sequence = [
                    {
                      choose = [
                        {
                          alias = "Burning -> proper shutdown through the remote; the stove-idle trigger cuts the plug once it has cooled";
                          conditions = [
                            {
                              condition = "state";
                              entity_id = "switch.living_room_stove_switch";
                              state = "on";
                            }
                            {
                              condition = "state";
                              entity_id = "binary_sensor.living_room_stove_is_maybe_burning";
                              state = "on";
                            }
                            {
                              condition = "template";
                              value_template = "{{ stove_cooldown_ok | bool or stove_manual_off_ok | bool }}";
                              alias = "Cooldown passed, or a manual off right after an ignition";
                            }
                            {
                              alias = "Really burning, not the ~50 W spike a plug toggle produces: the plug has been steady for 10 min";
                              condition = "template";
                              value_template = "{{ now() - states.switch.living_room_stove_switch.last_changed > timedelta(minutes=10) }}";
                            }
                          ];
                          sequence = [
                            {
                              action = "remote.send_command";
                              target = {
                                entity_id = "remote.living_room_universal_remote";
                              };
                              data = {
                                device = "poele";
                                command = "power";
                                num_repeats = 15;
                                delay_secs = 0;
                              };
                            }
                            {
                              action = "input_datetime.set_datetime";
                              target = {
                                entity_id = "input_datetime.heating_last_stove_command";
                              };
                              data = {
                                datetime = "{{ now().strftime('%Y-%m-%d %H:%M:%S') }}";
                              };
                            }
                          ];
                        }
                        {
                          alias = "Already off and cool -> cut the idle draw now";
                          conditions = [
                            {
                              condition = "state";
                              entity_id = "switch.living_room_stove_switch";
                              state = "on";
                            }
                            {
                              condition = "state";
                              entity_id = "binary_sensor.living_room_stove_is_maybe_burning";
                              state = "off";
                            }
                          ];
                          sequence = [
                            {
                              action = "switch.turn_off";
                              target = {
                                entity_id = "switch.living_room_stove_switch";
                              };
                            }
                          ];
                        }
                        {
                          alias = "Burning but a command was sent < 45 min ago (maybe still shutting down) -> tell me";
                          conditions = [
                            {
                              condition = "state";
                              entity_id = "binary_sensor.living_room_stove_is_maybe_burning";
                              state = "on";
                            }
                          ];
                          sequence = [
                            {
                              action = "notify.mobile_app_dafphone";
                              data = {
                                title = "Poêle pas éteint";
                                message = "Une commande a déjà été envoyée il y a moins de 45 min ; le poêle est peut-être encore en cycle d'extinction. Vérifie-le.";
                                data = {
                                  tag = "heating_stove";
                                  channel = "Chauffage";
                                  notification_icon = "mdi:fireplace-off";
                                  group = "Chauffage";
                                };
                              };
                            }
                          ];
                        }
                      ];
                    }
                  ];
                }
                {
                  conditions = [
                    {
                      condition = "template";
                      value_template = "{{ stove | trim == 'on' }}";
                    }
                  ];
                  sequence = [
                    {
                      "if" = [
                        {
                          condition = "state";
                          entity_id = "switch.living_room_stove_switch";
                          state = "off";
                        }
                      ];
                      "then" = [
                        {
                          action = "switch.turn_on";
                          target = {
                            entity_id = "switch.living_room_stove_switch";
                          };
                        }
                        {
                          alias = "Let the stove electronics boot before talking to it";
                          delay = {
                            minutes = 3;
                          };
                        }
                      ];
                    }
                    {
                      "if" = [
                        {
                          alias = "Off = idle draw right now (the 10-min max may still hold the plug-on spike)";
                          condition = "template";
                          value_template = ''
                            {{ states('sensor.living_room_stove_power') | float(0) < 30
                               and (is_state('binary_sensor.living_room_stove_is_maybe_burning', 'off')
                                    or (now() - states.switch.living_room_stove_switch.last_changed) < timedelta(minutes=10)) }}'';
                        }
                        {
                          condition = "template";
                          value_template = "{{ stove_cooldown_ok | bool }}";
                        }
                      ];
                      "then" = [
                        {
                          action = "remote.send_command";
                          target = {
                            entity_id = "remote.living_room_universal_remote";
                          };
                          data = {
                            device = "poele";
                            command = "power";
                            num_repeats = 15;
                            delay_secs = 0;
                          };
                        }
                        {
                          action = "input_datetime.set_datetime";
                          target = {
                            entity_id = "input_datetime.heating_last_stove_command";
                          };
                          data = {
                            datetime = "{{ now().strftime('%Y-%m-%d %H:%M:%S') }}";
                          };
                        }
                        {
                          alias = "Ignition draws ~320 W within a minute or two";
                          wait_template = "{{ states('sensor.living_room_stove_power') | float(0) > 100 }}";
                          timeout = {
                            minutes = 12;
                          };
                          continue_on_timeout = true;
                        }
                        {
                          "if" = [
                            {
                              condition = "template";
                              value_template = "{{ not wait.completed }}";
                            }
                          ];
                          "then" = [
                            {
                              action = "notify.mobile_app_dafphone";
                              data = {
                                title = "Poêle pas démarré";
                                message = "La commande d'allumage a été envoyée mais le poêle ne consomme rien depuis 12 min. Vérifie le Broadlink (alignement) ou allume-le à la main.";
                                data = {
                                  tag = "heating_stove";
                                  channel = "Chauffage";
                                  notification_icon = "mdi:fireplace-off";
                                  group = "Chauffage";
                                };
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
      ];
      variables = {
        off_season_temp = 7;
        inherit rooms;
        season = "{{ is_state('binary_sensor.global_is_cold_season', 'on') }}";
        # Mode Absent, or nobody home for 1 h (dafbox stays `home` all day, so
        # an empty house still got heated). The hour comes from the recorder: a
        # state's last_changed restarts at every HA restart.
        # Retour imminent overrides both and heats every room as if occupied.
        returning = "{{ is_state('input_select.heating_mode', 'Retour imminent') }}";
        away = ''
          {{ not is_state('input_select.heating_mode', 'Retour imminent')
             and (is_state('input_select.heating_mode', 'Absent')
                  or (is_state('binary_sensor.global_home_is_occupied', 'off')
                      and states('sensor.heating_home_occupied_last_hour') | float(1) < 0.02)) }}'';
        stove_start = "{% set a = states('sensor.dafphone_next_alarm') | as_datetime(none) %}{% set a = a | as_local if a is not none else none %}{% set al = a.strftime('%H:%M') if a is not none and a.date() == now().date() else '' %}{% set start = ['06:00', (a - timedelta(hours=1)).strftime('%H:%M')] | max if '06:00' <= al <= '10:00' else '06:00' %}{{ start }}";
      };
      mode = "queued";
      max = 10;
      trace = {
        stored_traces = 50;
      };
    }
  ];
}
