# Pellet tank of the living room stove: how long the current fill will last,
# and a phone alert when it is time to top it up.
#
# There is no level sensor. The tank holds one 15 kg bag; the estimate counts
# the hours the stove has actually burned since the last refill
# (binary_sensor.heating_stove_burning, see heating_usage.nix) against the
# burn time a full tank lasts (input_number.stove_pellets_autonomy).
#
# That autonomy calibrates itself: press "Réservoir vide" when the stove runs
# dry, and the hours burned on that fill become the new autonomy. Until then it
# is a guess (15 h, about 1 kg/h).
#
# Refill: the dashboard button or the notification's "Rechargé" action.
# Each refill takes one bag off input_number.stove_pellets_bags (the stock).
_:

let
  burning = "binary_sensor.heating_stove_burning";
  refilledAt = "input_datetime.stove_pellets_refilled_at";
  autonomy = "input_number.stove_pellets_autonomy";
  bags = "input_number.stove_pellets_bags";
  burned = "sensor.stove_pellets_burned";
  remaining = "sensor.stove_pellets_remaining";
  # Alert when this many burn hours are left
  warnHours = 2;

  tag = "stove_pellets";
  refillAction = "STOVE_PELLETS_REFILLED";

  notify = title: message: {
    action = "notify.mobile_app_dafphone";
    data = {
      inherit title message;
      data = {
        inherit tag;
        group = "Chauffage";
        channel = "Chauffage";
        notification_icon = "mdi:sack";
        actions = [
          {
            action = refillAction;
            title = "Rechargé";
          }
        ];
      };
    };
  };
in
{
  input_datetime.stove_pellets_refilled_at = {
    name = "Poêle · Granulés rechargés le";
    icon = "mdi:sack";
    has_date = true;
    has_time = true;
  };

  # No `initial`: it would reset the learned value on every restart.
  input_number.stove_pellets_autonomy = {
    name = "Poêle · Autonomie d'un réservoir";
    icon = "mdi:timer-sand";
    min = 3;
    max = 60;
    step = 0.5;
    unit_of_measurement = "h";
    mode = "box";
  };

  # Bags in stock, one used per refill. Set by hand when buying more.
  input_number.stove_pellets_bags = {
    name = "Poêle · Sacs de granulés en stock";
    icon = "mdi:sack";
    min = 0;
    max = 100;
    step = 1;
    mode = "box";
  };

  input_button = {
    stove_pellets_refilled = {
      name = "Poêle · Granulés rechargés";
      icon = "mdi:sack";
    };
    stove_pellets_empty = {
      name = "Poêle · Réservoir vide";
      icon = "mdi:sack-outline";
    };
  };

  platformSensors = [
    {
      platform = "history_stats";
      name = "Stove pellets burned";
      unique_id = "dafos.sensor.stove_pellets_burned";
      entity_id = burning;
      state = "on";
      type = "time";
      start = "{{ states('${refilledAt}') | as_datetime(now()) | as_local }}";
      end = "{{ now() }}";
    }
  ];

  templates = [
    {
      sensor = [
        {
          name = "Poêle · Granulés restants";
          unique_id = "dafos.sensor.stove_pellets_remaining";
          default_entity_id = remaining;
          icon = "mdi:sack";
          unit_of_measurement = "h";
          state_class = "measurement";
          state = "{{ [states('${autonomy}') | float(0) - states('${burned}') | float(0), 0] | max | round(1) }}";
          availability = "{{ has_value('${autonomy}') and has_value('${burned}') }}";
          attributes.percent = "{{ ([1 - states('${burned}') | float(0) / [states('${autonomy}') | float(0), 1] | max, 0] | max * 100) | round(0) | int }}";
        }
      ];
    }
  ];

  automations = [
    {
      id = "dafos_stove_pellets";
      alias = "Poêle · Granulés";
      description = "Estimates the pellet tank from burn hours since the last refill and alerts when about ${toString warnHours} h are left. Managed in Nix (modules/nixos/services/home-assistant/pellets.nix).";
      mode = "queued";
      triggers = [
        {
          trigger = "state";
          entity_id = "input_button.stove_pellets_refilled";
          not_to = [ "unavailable" ];
          id = "refilled";
        }
        {
          trigger = "event";
          event_type = "mobile_app_notification_action";
          event_data.action = refillAction;
          id = "refilled";
        }
        {
          trigger = "state";
          entity_id = "input_button.stove_pellets_empty";
          not_to = [ "unavailable" ];
          id = "empty";
        }
        {
          trigger = "numeric_state";
          entity_id = remaining;
          below = warnHours;
          id = "low";
        }
        {
          trigger = "numeric_state";
          entity_id = remaining;
          below = 0.1;
          id = "out";
        }
      ];
      actions = [
        {
          choose = [
            {
              alias = "Refilled: restart the count, drop the alert";
              conditions = [
                {
                  condition = "trigger";
                  id = "refilled";
                }
              ];
              sequence = [
                {
                  alias = "One bag less in stock";
                  action = "input_number.set_value";
                  target.entity_id = bags;
                  data.value = "{{ [states('${bags}') | int(0) - 1, 0] | max }}";
                }
                {
                  action = "input_datetime.set_datetime";
                  target.entity_id = refilledAt;
                  data.timestamp = "{{ now().timestamp() }}";
                }
                {
                  action = "notify.mobile_app_dafphone";
                  data = {
                    message = "clear_notification";
                    data.tag = tag;
                  };
                }
              ];
            }
            {
              alias = "Ran dry: the hours burned on this fill become the autonomy";
              conditions = [
                {
                  condition = "trigger";
                  id = "empty";
                }
                {
                  alias = "Ignore a press right after a refill";
                  condition = "numeric_state";
                  entity_id = burned;
                  above = 3;
                }
              ];
              sequence = [
                {
                  action = "input_number.set_value";
                  target.entity_id = autonomy;
                  data.value = "{{ (states('${burned}') | float * 2) | round(0) / 2 }}";
                }
                (notify "Autonomie du poêle mise à jour" "Un réservoir dure environ {{ states('${autonomy}') }} h de combustion. Recharge puis appuie sur « Rechargé ».")
              ];
            }
            {
              alias = "Low: time to top up";
              conditions = [
                {
                  condition = "trigger";
                  id = "low";
                }
              ];
              sequence = [
                (notify "Granulés bientôt épuisés" "Environ {{ states('${remaining}') }} h de combustion restantes (sur {{ states('${autonomy}') }} h). Pense à remettre un sac ({{ states('${bags}') | int(0) }} en stock).")
              ];
            }
            {
              alias = "Out: the estimate says empty";
              conditions = [
                {
                  condition = "trigger";
                  id = "out";
                }
              ];
              sequence = [
                (notify "Réservoir de granulés vide ?" "L'estimation est à zéro. Recharge, ou appuie sur « Réservoir vide » sur le dashboard si le poêle s'est arrêté, pour recalibrer.")
              ];
            }
          ];
        }
      ];
    }
  ];
}
