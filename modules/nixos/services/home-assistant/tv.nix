# Veranda TV (daftv) scripts: the start-up, called when the Google TV
# Streamer wakes ("Véranda · daftv Controller", "Véranda · Cube Controller",
# "Véranda · Switch Extras"), the speakers' own start-up (also on the cube and
# the Maison dashboard's TV pop-up), and the volume steps.
#
# They were UI scripts (scripts/media_players.yaml) that targeted devices by
# id; the ZHA → Zigbee2MQTT move of the TV plug (2026-10-20) and re-added
# remote and streamer integrations left them pointing at removed devices, and
# HA disabled the start-up. Entities here, so a re-pair only needs the entity
# id kept.
_:

let
  plug = "switch.veranda_tv_plug_switch";
  # The infrared blaster holding the learned `tv_speakers` commands.
  remote = "remote.living_room_universal_remote";
  # The Google TV Streamer.
  streamer = "media_player.televiseur_living_room_2";

  speakers = alias: command: repeats: {
    inherit alias;
    action = "remote.send_command";
    target.entity_id = remote;
    data = {
      device = "tv_speakers";
      inherit command;
      num_repeats = repeats;
      delay_secs = 0.4;
      hold_secs = 0;
    };
  };

  # The speakers by infrared and the streamer's own volume, together.
  volumeStep = direction: {
    alias = "${if direction == "up" then "Increase" else "Decrease"} TV volume";
    description = "Five infrared steps on the speakers and three on the streamer. Managed in Nix (modules/nixos/services/home-assistant/tv.nix).";
    icon = "mdi:volume-${if direction == "up" then "plus" else "minus"}";
    sequence = [
      {
        parallel = [
          (speakers "Speakers volume ${direction}" "vol_${direction}" 5)
          {
            repeat = {
              count = 3;
              sequence = [
                {
                  action = "media_player.volume_${direction}";
                  target.entity_id = streamer;
                }
              ];
            };
          }
        ];
      }
    ];
  };

  speakersStep = direction: {
    alias = "${if direction == "up" then "Increase" else "Decrease"} TV speakers volume";
    description = "Two infrared steps on the TV speakers. Managed in Nix (modules/nixos/services/home-assistant/tv.nix).";
    icon = "mdi:volume-${if direction == "up" then "plus" else "minus"}";
    mode = "queued";
    sequence = [ (speakers "Speakers volume ${direction}" "vol_${direction}" 2) ];
  };
in
{
  scripts = {
    turn_on_and_setup_living_room_tv = {
      alias = "Turn On and Setup TV";
      description = "Powers the TV plug, then turns the speakers on, on the optical input, and raises the volume. Managed in Nix (modules/nixos/services/home-assistant/tv.nix).";
      icon = "mdi:television";
      mode = "single";
      sequence = [
        {
          alias = "Only from a cold start: the plug is off";
          condition = "state";
          entity_id = plug;
          state = "off";
        }
        {
          action = "switch.turn_on";
          target.entity_id = plug;
        }
        # The TV boots before it takes the speakers' input
        { delay.seconds = 15; }
        { action = "script.turn_on_tv_speakers"; }
        { delay.seconds = 10; }
        { action = "script.increase_tv_volume"; }
      ];
    };

    # The learned `power` code is the remote's power key, which on IR speakers
    # is usually a toggle: from the cube or the dashboard, run it only while
    # they are off
    turn_on_tv_speakers = {
      alias = "Turn On TV Speakers";
      description = "Turns the TV speakers on by infrared and selects the optical input (the TV). Managed in Nix (modules/nixos/services/home-assistant/tv.nix).";
      icon = "mdi:speaker";
      mode = "single";
      sequence = [
        (speakers "Turn on the TV speakers" "power" 1)
        { delay.seconds = 10; }
        (speakers "Select the optical input" "opt1" 1)
      ];
    };

    # The speakers alone, for the dashboard: the streamer may be asleep
    increase_tv_speakers_volume = speakersStep "up";
    decrease_tv_speakers_volume = speakersStep "down";

    increase_tv_volume = volumeStep "up";
    decrease_tv_volume = volumeStep "down";
  };
}
