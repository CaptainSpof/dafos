{
  config,
  lib,
  namespace,
  ...
}:

let
  inherit (lib.${namespace}) enabled;
in
{
  imports = [
    ./hardware.nix
    ./disko.nix
  ];

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  dafos = {
    archetypes = {
      workstation = enabled;
      gaming = enabled;
    };

    apps = {
      qbittorrent = enabled;
    };

    display-managers = {
      enable = true;
      defaultSession = "niri";
      autoLogin = {
        enable = true;
        user = config.${namespace}.user.name;
      };
      dms-greeter.enable = true;
    };

    hardware = {
      cpu.amd = enabled;
      gpu.amd = enabled;
    };

    services.syncthing = enabled;
    services.sunshine = enabled;

    suites = {
      desktop = enabled;
      development = enabled;
    };

    system = {
      kanata = enabled;

      networking = {
        enable = true;
        optimizeTcp = true;
      };
    };
  };

  # Pin HDMI/DP audio to the LG monitor (the only display with speakers).
  # The Navi 31 GPU exposes several HDMI/DP outputs but can only run one stereo
  # audio profile at a time. On a fresh install WirePlumber has no saved state
  # and falls back to the higher-priority M27Q port (output:hdmi-stereo), which
  # has no speakers — leaving the box silent. Force the LG's port instead.
  # Device name is the GPU audio function at PCI 03:00.1 (stable on this board).
  services.pipewire.wireplumber.extraConfig."99-pin-lg-audio" = {
    "monitor.alsa.rules" = [
      {
        matches = [ { "device.name" = "alsa_card.pci-0000_03_00.1"; } ];
        actions.update-props."device.profile" = "output:hdmi-stereo-extra1";
      }
      # Give the LG's HDMI sink a human-readable name in volume UIs.
      # It's the LG IPS FULLHD on the physical HDMI-A-1 port (ALSA hdmi:0,1).
      {
        matches = [ { "node.name" = "alsa_output.pci-0000_03_00.1.hdmi-stereo-extra1"; } ];
        actions.update-props = {
          "node.description" = "LG IPS FULLHD (HDMI-A-1)";
          "node.nick" = "LG Monitor";
        };
      }
    ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Can't touch this 🔨
}
