# Netatmo watchdog, replacing the UI automation "Global · Reload Netatmo if
# unavailable", which only reloaded the config entry.
#
# A reload rarely helped: unloading calls the Netatmo API (dropping the
# webhook) with no timeout, and with the token refreshed through Home
# Assistant Cloud that call could wait forever, leaving the entry stuck in
# `unload_in_progress` until HA restarted (seen 2026-10-19).
#
# So: reload while the entry is in a state a reload can fix; once it is stuck,
# or a reload did not bring the thermostat back, restart HA. At most one
# restart a day, between 07:00 and 22:30 (never during the night), announced
# on the phone. Out of that window it retries every 30 min.
#
# When the API answers (the schedule select is available) but the thermostat
# is down, Netatmo reports it unreachable; only a warning is sent then.
_:

let
  thermostat = "climate.sejour";
  lastRestart = "input_datetime.netatmo_watchdog_last_restart";
  tag = "netatmo";

  notify = title: message: {
    action = "notify.mobile_app_dafphone";
    data = {
      inherit title message;
      data = {
        inherit tag;
        group = "Monitoring";
        channel = "Monitoring";
        notification_icon = "mdi:thermostat";
        # Retries every 30 min replace it without ringing again
        alert_once = true;
      };
    };
  };

  # The entry is found through the thermostat: its id changes whenever the
  # integration is set up again (it moved to own application credentials on
  # 2026-10-19).
  entryState = "config_entry_attr(config_entry_id('${thermostat}'), 'state') | string";
  down = "is_state('${thermostat}', 'unavailable')";
  # The home-level schedule select only depends on the API answering. When it
  # is fine while the thermostat is down, Netatmo itself reports the thermostat
  # unreachable (radio to the relay, or the relay's Wi-Fi): a reload or restart
  # cannot fix that (seen 2026-10-20/21, 44 min to 1 h outages), so only warn.
  apiUp = "has_value('select.dafnanterre')";
in
{
  input_datetime.netatmo_watchdog_last_restart = {
    name = "Netatmo watchdog · Last restart";
    icon = "mdi:restart-alert";
    has_date = true;
    has_time = true;
  };

  automations = [
    {
      id = "dafos_netatmo_watchdog";
      alias = "Netatmo · Watchdog";
      description = "Warns when Netatmo reports the thermostat unreachable; reloads the Netatmo integration when the API itself is down 10 min, and restarts HA (at most once a day, 07:00-22:30) when the entry is stuck unloading or a reload did not help. Managed in Nix (modules/nixos/services/home-assistant/netatmo_watchdog.nix).";
      mode = "single";
      triggers = [
        {
          trigger = "state";
          entity_id = thermostat;
          to = "unavailable";
          "for".minutes = 10;
          id = "down";
        }
        {
          trigger = "time_pattern";
          minutes = "/30";
          id = "retry";
        }
        {
          trigger = "state";
          entity_id = thermostat;
          from = "unavailable";
          id = "back";
        }
      ];
      actions = [
        {
          choose = [
            {
              alias = "Back: drop the alerts";
              conditions = [
                {
                  condition = "trigger";
                  id = "back";
                }
              ];
              sequence = [
                {
                  action = "notify.mobile_app_dafphone";
                  data = {
                    message = "clear_notification";
                    data.tag = tag;
                  };
                }
                {
                  action = "persistent_notification.dismiss";
                  data.notification_id = tag;
                }
              ];
            }
            {
              alias = "Down for 10 min, but the API answers: the thermostat itself is unreachable, warn only";
              conditions = [
                {
                  condition = "template";
                  value_template = "{{ ${down} and ${apiUp} and now() - states.${thermostat}.last_changed > timedelta(minutes=10) }}";
                }
              ];
              sequence = [
                (notify "Thermostat Netatmo injoignable" "Netatmo répond, mais ne joint plus le thermostat depuis {{ ((now() - states.${thermostat}.last_changed).total_seconds() / 60) | int }} min. Vérifie le relais (Wi-Fi) et le thermostat (piles, signal radio). Le poêle se règle sur la véranda en attendant.")
              ];
            }
            {
              alias = "Down for 10 min or more, API down too: repair";
              conditions = [
                {
                  condition = "template";
                  value_template = "{{ ${down} and now() - states.${thermostat}.last_changed > timedelta(minutes=10) }}";
                }
              ];
              sequence = [
                {
                  alias = "Reload, unless the entry is stuck in a transition";
                  "if" = [
                    {
                      condition = "template";
                      value_template = "{{ ${entryState} in ['loaded', 'setup_retry', 'setup_error', 'not_loaded'] }}";
                    }
                  ];
                  "then" = [
                    {
                      action = "homeassistant.reload_config_entry";
                      target.entity_id = thermostat;
                      # A reload that hangs must not hang the watchdog
                      continue_on_error = true;
                    }
                    {
                      wait_template = "{{ not ${down} }}";
                      timeout.minutes = 3;
                    }
                  ];
                }
                {
                  alias = "Still down: restart HA, if allowed now";
                  "if" = [
                    {
                      condition = "template";
                      value_template = "{{ ${down} }}";
                    }
                  ];
                  "then" = [
                    {
                      "if" = [
                        {
                          condition = "time";
                          after = "07:00:00";
                          before = "22:30:00";
                        }
                        {
                          condition = "template";
                          value_template = "{{ now() - (states('${lastRestart}') | as_datetime(as_datetime('2000-01-01')) | as_local) > timedelta(hours=24) }}";
                        }
                      ];
                      "then" = [
                        {
                          action = "input_datetime.set_datetime";
                          target.entity_id = lastRestart;
                          data.timestamp = "{{ now().timestamp() }}";
                        }
                        (notify "Netatmo indisponible" "Le rechargement n'a pas suffi (intégration : {{ ${entryState} }}). Redémarrage de Home Assistant.")
                        { delay.seconds = 5; }
                        { action = "homeassistant.restart"; }
                      ];
                      "else" = [
                        (notify "Netatmo indisponible" "Rechargement sans effet (intégration : {{ ${entryState} }}). Redémarrage de HA reporté : déjà fait dans les dernières 24 h, ou pendant la nuit.")
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
}
