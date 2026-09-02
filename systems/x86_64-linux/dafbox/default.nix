{
  config,
  lib,
  namespace,
  ...
}:

let
  inherit (lib) mkForce;
  inherit (lib.${namespace}) enabled;
in
{
  imports = [
    ./hardware.nix
    ./disko.nix
  ];

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # vsock transport for Claude Desktop's Cowork VM (claude-desktop-fhs)
  boot.kernelModules = [ "vhost_vsock" ];

  # Both off, not merely relaxed. blocky serves plain DNS on :53 with no
  # listener on 853, and dafoltop's firewall DROPS 853 rather than rejecting
  # it — measured at 6s to time out versus 5ms for a refused port. So
  # "opportunistic" is no better than "true" here: resolved probes 853 on
  # every lookup and waits out a full TCP timeout instead of downgrading.
  # Encryption to the internet is unaffected, since blocky is the DoT
  # terminator and forwards upstream over tcp-tls:1.1.1.1:853; only this LAN
  # hop is plaintext, and Cloudflare still validates DNSSEC on blocky's behalf.
  services.resolved.settings.Resolve = {
    DNSOverTLS = mkForce false;
    DNSSEC = mkForce false;
  };

  dafos = {
    archetypes = {
      workstation = enabled;
      gaming = enabled;
    };

    apps = {
      qbittorrent = enabled;
    };

    programs.graphical.apps.games.sisr = {
      enable = true;
      # Overlay felt intrusive fullscreen; run it as a normal window instead.
      # showWindow must be on too, or fullscreen=false alone just makes SISR
      # tray-only with no window at all (see the sisr module for why).
      fullscreen = false;
      showWindow = true;
      # The 8BitDo Ultimate 2 (2dc8:310b) exposes a keyboard and a mouse HID
      # interface alongside its pad; keep SISR from grabbing and re-emulating it
      # so it can't interfere with the other controllers.
      ignoreControllers = [ "0x2dc8/0x310b" ];
    };

    # Keep the Sunshine-forwarded Xbox pad (045e:02ea) out of Steam Input's grab so it
    # stays a distinct controller for Player 2 in emulators, instead of SISR folding it
    # into the Player 1 pad via its forced Steam Input layout. See the SISR module.
    programs.graphical.apps.games.steam.ignoreControllers = [ "0x045e/0x02ea" ];

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
      sensors = enabled;
    };

    services.syncthing = enabled;
    services.sunshine = enabled;
    services.moondeck-buddy = enabled;

    suites = {
      desktop = enabled;
      development = {
        enable = true;
        podman = enabled;
      };
    };

    system = {
      kanata = enabled;

      networking = {
        enable = true;
        optimizeTcp = true;
        nameservers = [ "192.168.0.10" ];
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
