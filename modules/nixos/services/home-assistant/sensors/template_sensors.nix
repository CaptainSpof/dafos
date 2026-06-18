# Template sensors in the modern `template:` integration format.
#
# Migrated from the legacy `sensor: - platform: template` format removed in HA
# 2026.6. Consumed under `services.home-assistant.config.template` (see
# default.nix) as a `{ sensor = [...]; }` block.
#
# The unique_ids are unchanged from the legacy definitions, so HA reattaches to
# the existing registry entries and keeps their entity_ids and history.
[
  {
    name = "dafphone";
    unique_id = "dafos.sensor.maybe_dafphone_charging";
    state = ''
      {% if is_state('binary_sensor.phone_is_charging', 'on') %}
        charging
      {% else %}
        not charging
      {% endif %}
    '';
  }
  {
    name = "Maybe Dashboard Warning";
    unique_id = "dafos.sensor.maybe_dashboard_warning";
    state = ''
      {{ label_entities('dashboard-warning') | expand | selectattr('state', 'eq', 'on') | map(attribute='entity_id') | list | count > 0 }}
    '';
  }
]
