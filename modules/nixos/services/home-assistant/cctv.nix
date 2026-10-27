# Arming and disarming the indoor camera from the dashboard.
#
# The camera is driven by the dafindoorcam_settings event, which the UI
# automation "Living Room · Dafindoorcam Controller" turns into a preset move
# plus the privacy switch, in the right order (the presets are unavailable
# while privacy is on). Toggling switch.dafindoorcam_privacy alone leaves the
# lens wherever it was. The frontend cannot fire an event, so this script
# does.
_:

{
  scripts.camera_privacy = {
    alias = "Camera · Privacy";
    description = "Arms (watching) or disarms (privacy) the indoor camera through its controller.";
    mode = "queued";
    icon = "mdi:cctv";
    fields.privacy = {
      description = "armed: the camera watches. disarmed: privacy preset, then privacy mode.";
      example = "armed";
      selector.select.options = [
        "armed"
        "disarmed"
      ];
    };
    sequence = [
      {
        event = "dafindoorcam_settings";
        event_data.privacy = "{{ privacy }}";
      }
    ];
  };
}
