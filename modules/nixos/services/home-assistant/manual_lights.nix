# Manual mode for the living room lights, as the kitchen has it: the STYRBAR
# remote's short "on" puts the room in manual mode (sensor-light bypass on),
# "off" ends it. The remote still drives the light itself through
# Living Room · Hook Ceiling Lights (lsismeiro/light.yaml); this only follows
# its presses. Living Room · Sensor Lights (UI, Blackshome blueprint) keeps the
# lights as they are while the bypass is on and turns it off after 180 min
# (Bypass Auto OFF, option "keep the current state"); the Maison dashboard's
# ring around the room icon shows that time (origami/rooms.nix, `manual`).
_:

let
  remote = "ffc89bc7ad1471db67e6371de8fdcb70"; # IKEA E2001/E2002 STYRBAR
  bypass = "input_boolean.living_room_lights_bypass_toggle";

  press = subtype: {
    trigger = "device";
    domain = "zha";
    device_id = remote;
    type = "remote_button_short_press";
    inherit subtype;
    id = subtype;
  };
in
{
  automations = [
    {
      id = "dafos_living_room_manual_lights";
      alias = "Living Room · Manual Lights";
      description = "The STYRBAR remote's on/off presses start and end the living room's manual mode (sensor-light bypass). Managed in Nix (modules/nixos/services/home-assistant/manual_lights.nix).";
      mode = "queued";
      triggers = [
        (press "turn_on")
        (press "turn_off")
      ];
      actions = [
        {
          action = "input_boolean.turn_{{ 'on' if trigger.id == 'turn_on' else 'off' }}";
          target.entity_id = bypass;
        }
      ];
    }
  ];
}
