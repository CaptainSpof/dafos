# Zigbee and Matter devices that dropped off, with a phone alert.
#
# A device counts as offline when none of its entities has a value: Zigbee2MQTT
# marks the whole device unavailable (`availability = true`: 10 min for mains
# devices, 25 h of silence for battery ones), the Matter server does the same
# when a node stops answering. Remotes are covered too, unlike
# sensor.maison_offline, which only watches the dashboard's entities.
#
# On 2026-10-26 the Thread radio on dafpi had been crash-looping for two days
# and took the three Matter devices with it, unnoticed; this is what would
# have said so.
#
# Devices expected to stay off (unplugged lamp, dead sensor waiting for a
# battery) are skipped once given the label "Hors ligne attendu".
#
# Only devices newly offline alert (the list is refreshed every 5 minutes and
# must hold for 30); the notification lists them with the running total, and
# is cleared once everything is back.
_:

let
  sensor = "sensor.devices_offline";
  ignoreLabel = "hors_ligne_attendu";
  tag = "devices_offline";

  # Zigbee2MQTT devices (identifier zigbee2mqtt_0x…, not the bridge) and every
  # Matter node.
  offlineLoop = ''
    {%- set ns = namespace(names=[]) -%}
    {%- for dev in (integration_entities('mqtt') + integration_entities('matter')) | map('device_id') | reject('none') | unique -%}
      {%- set ids = device_attr(dev, 'identifiers') | map('join', ':') | join(' ') -%}
      {%- if (ids is search('zigbee2mqtt_0x') or ids is search('(^| )matter:'))
            and '${ignoreLabel}' not in labels(dev)
            and device_entities(dev) | select('has_value') | list | count == 0 -%}
        {%- set ns.names = ns.names + [device_attr(dev, 'name_by_user') or device_attr(dev, 'name')] -%}
      {%- endif -%}
    {%- endfor -%}
  '';
  offline = offlineLoop + "{{ ns.names | sort }}";
  offlineCount = offlineLoop + "{{ ns.names | count }}";
in
{
  templates = [
    {
      # Polled: re-rendering on every state change of a few hundred entities
      # is not worth it for an alert that waits 30 minutes anyway. No
      # homeassistant-start trigger: at start the MQTT entities are not
      # published yet and every Zigbee device reads offline (82 of them).
      triggers = [
        {
          trigger = "time_pattern";
          minutes = "/5";
        }
      ];
      sensor = [
        {
          name = "Appareils hors ligne";
          unique_id = "dafos.sensor.devices_offline";
          default_entity_id = sensor;
          icon = "mdi:access-point-network-off";
          state = offlineCount;
          attributes.devices = offline;
        }
      ];
    }
  ];

  automations = [
    {
      id = "dafos_devices_offline";
      alias = "Appareils hors ligne";
      description = "Alerts when a Zigbee2MQTT or Matter device has been offline for 30 minutes. Managed in Nix (modules/nixos/services/home-assistant/device_watch.nix).";
      mode = "queued";
      triggers = [
        {
          trigger = "state";
          entity_id = sensor;
          attribute = "devices";
          "for" = "00:30:00";
        }
      ];
      conditions = [
        {
          alias = "Not the first value after a restart or a new sensor";
          condition = "template";
          value_template = "{{ trigger.from_state is not none and trigger.from_state.attributes.devices is defined }}";
        }
      ];
      variables = {
        before = "{{ trigger.from_state.attributes.devices | default([]) }}";
        now_offline = "{{ trigger.to_state.attributes.devices | default([]) }}";
        new = "{{ now_offline | reject('in', before) | list }}";
      };
      actions = [
        {
          choose = [
            {
              alias = "Everything back: drop the alert";
              conditions = [
                {
                  condition = "template";
                  value_template = "{{ now_offline | count == 0 }}";
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
              ];
            }
            {
              alias = "A device newly offline";
              conditions = [
                {
                  condition = "template";
                  value_template = "{{ new | count > 0 }}";
                }
              ];
              sequence = [
                {
                  action = "notify.mobile_app_dafphone";
                  data = {
                    title = "{{ new | join(', ') }} hors ligne";
                    message = "Depuis 30 min. {{ now_offline | count }} appareil(s) Zigbee/Matter hors ligne en tout : {{ now_offline | join(', ') }}.";
                    data = {
                      inherit tag;
                      group = "Monitoring";
                      channel = "Monitoring";
                      importance = "high";
                      notification_icon = "mdi:access-point-network-off";
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
