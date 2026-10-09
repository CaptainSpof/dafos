{
  # Scratch store for the "Global · Window Airing Advice" automation: holds the
  # last airing advice that was pushed to the phone, so the automation can skip
  # re-notifying when the recomputed advice is identical (deduplication).
  window_airing_last_advice = {
    name = "Window Airing · Last Advice";
    icon = "mdi:window-open-variant";
    max = 255;
  };
  # Scratch store for the "Véranda · Color Panel Night Mode" automation: the
  # status the panel shows (JSON: on, rgb, brightness), saved when it goes dark
  # for the night and updated by any status set overnight, restored in the
  # morning. A helper rather than scene.create, which a night deploy (HA
  # restart) would wipe.
  veranda_color_panel_saved_state = {
    name = "Véranda · Color Panel saved state";
    icon = "mdi:palette";
    max = 255;
  };
}
