{
  # Scratch store for the "Global · Window Airing Advice" automation: holds the
  # last airing advice that was pushed to the phone, so the automation can skip
  # re-notifying when the recomputed advice is identical (deduplication).
  window_airing_last_advice = {
    name = "Window Airing · Last Advice";
    icon = "mdi:window-open-variant";
    max = 255;
  };
}
