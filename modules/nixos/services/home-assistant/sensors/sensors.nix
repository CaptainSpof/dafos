# Non-template `sensor:` platform entries. The legacy template sensors that used
# to live here were moved to ./template_sensors.nix (the modern `template:`
# integration) when HA 2026.6 removed the legacy `platform: template` format.
# `history_stats` is its own integration and is unaffected, so it stays here.
[
  {
    platform = "history_stats";
    entity_id = "sensor.veranda_tv_plug_power";
    state = "off";
    name = "Véranda · daftv Power Stats";
    unique_id = "dafos.sensor.veranda_daftv_power_stats";
    end = "{{ now() }}";
    duration.hours = 6;
  }
  {
    platform = "history_stats";
    entity_id = "sensor.desk_plug_power";
    state = "off";
    name = "Desk · dafbox Power Stats";
    unique_id = "dafos.sensor.desk_dafbox_power_stats";
    end = "{{ now() }}";
    duration.hours = 6;
  }
]
