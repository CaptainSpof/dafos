# Household statuses that light the veranda colour panel (finished appliances,
# mail in the box) as Home Assistant notifications, so that dismissing one
# clears its status and the panel follows:
# - status on: a persistent notification appears (the Maison dashboard's
#   notifications card lists them);
# - that notification dismissed, from the dashboard or HA's own list, or the
#   phone notification with the same tag swiped away: the status goes off;
# - status off by any other path (the phone's "Vidé" button, a new cycle): the
#   persistent notification goes away.
# The panel itself is driven only by automation.veranda_color_panel_status,
# which watches these booleans.
{ lib }:

let
  inherit (lib) concatMap map;

  statuses = [
    {
      key = "dishwasher";
      boolean = "input_boolean.kitchen_dishwasher_is_finished";
      # Tag of the phone notification sent by Household · Appliances
      tag = "appliance_dishwasher";
      title = "Lave-vaisselle terminé";
      message = "La vaisselle est propre.";
    }
    {
      key = "washing_machine";
      boolean = "input_boolean.laundry_washing_machine_is_finished";
      tag = "appliance_washing_machine";
      title = "Lave-linge terminé";
      message = "Le linge est lavé.";
    }
    {
      key = "dryer";
      boolean = "input_boolean.laundry_dryer_is_finished";
      tag = "appliance_dryer";
      title = "Sèche-linge terminé";
      message = "Le linge est sec.";
    }
    {
      key = "mail";
      boolean = "input_boolean.outdoor_check_mailbox";
      # Tag of Outdoor · Mailbox Notification
      tag = "mail";
      title = "Courrier";
      message = "Du courrier est arrivé.";
    }
  ];

  id = s: "status_${s.key}";

  create = s: {
    action = "persistent_notification.create";
    data = {
      notification_id = id s;
      inherit (s) title message;
    };
  };

  statusOff = s: {
    action = "input_boolean.turn_off";
    target.entity_id = s.boolean;
  };
in
{
  automations = [
    {
      id = "dafos_household_status_notices";
      alias = "Household · Status Notices";
      description = "Mirrors the colour panel statuses (finished appliances, mail) as persistent notifications; dismissing one, or swiping the phone notification, turns the status off. Managed in Nix (modules/nixos/services/home-assistant/status_notices.nix).";
      mode = "queued";
      triggers =
        concatMap (s: [
          {
            trigger = "state";
            entity_id = s.boolean;
            to = "on";
            id = "on-${s.key}";
          }
          {
            trigger = "state";
            entity_id = s.boolean;
            from = "on";
            to = "off";
            id = "off-${s.key}";
          }
          {
            trigger = "persistent_notification";
            notification_id = id s;
            update_type = [ "removed" ];
            id = "dismissed-${s.key}";
          }
          {
            trigger = "event";
            event_type = "mobile_app_notification_cleared";
            event_data.tag = s.tag;
            id = "dismissed-${s.key}";
          }
        ]) statuses
        ++ [
          {
            trigger = "homeassistant";
            event = "start";
            id = "sync";
          }
        ];
      actions = [
        {
          choose =
            concatMap (s: [
              {
                conditions = [
                  {
                    condition = "trigger";
                    id = "on-${s.key}";
                  }
                ];
                sequence = [ (create s) ];
              }
              {
                conditions = [
                  {
                    condition = "trigger";
                    id = "off-${s.key}";
                  }
                ];
                sequence = [
                  {
                    action = "persistent_notification.dismiss";
                    data.notification_id = id s;
                  }
                ];
              }
              {
                alias = "${s.title}: dismissed, the status goes off";
                conditions = [
                  {
                    condition = "trigger";
                    id = "dismissed-${s.key}";
                  }
                  {
                    condition = "state";
                    entity_id = s.boolean;
                    state = "on";
                  }
                ];
                sequence = [ (statusOff s) ];
              }
            ]) statuses
            ++ [
              {
                alias = "After a restart: one notification per status still on";
                conditions = [
                  {
                    condition = "trigger";
                    id = "sync";
                  }
                ];
                sequence = map (s: {
                  "if" = [
                    {
                      condition = "state";
                      entity_id = s.boolean;
                      state = "on";
                    }
                  ];
                  "then" = [ (create s) ];
                }) statuses;
              }
            ];
        }
      ];
    }
  ];
}
