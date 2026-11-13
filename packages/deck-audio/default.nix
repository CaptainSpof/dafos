{
  writeShellApplication,
  systemd,
  pulseaudio,
  libnotify,
  coreutils,
  gnugrep,
  gawk,
}:
# Stream Deck Audio page on dafbox: send all sound to the dafcans headphones
# (connecting them and forcing A2DP, not the mono headset profile) or to the
# LG monitor's speakers. Moves the streams already playing, not just the default.
writeShellApplication {
  name = "deck-audio";
  runtimeInputs = [
    systemd # busctl
    pulseaudio
    libnotify
    coreutils
    gnugrep
    gawk
  ];
  text = ''
    mac=2C:BE:EE:4E:7B:8D # dafcans
    lg=alsa_output.pci-0000_03_00.1.hdmi-stereo-extra1

    sink_of() { pactl list short sinks | awk -v p="$1" 'index($2, p) == 1 { print $2; exit }'; }

    # dafbox has two adapters (onboard hci0, USB dongle hci1) and dafcans is
    # paired on both; bluetoothctl only uses the default one. Go through
    # D-Bus, the dongle first (reverse sort): that is where it plays LDAC.
    devs() { busctl tree org.bluez --list | grep "/dev_''${mac//:/_}$" | sort -r; }
    connected() { [ "$(busctl get-property org.bluez "$1" org.bluez.Device1 Connected)" = "b true" ]; }
    bt_connect() {
      for d in $(devs); do connected "$d" && return 0; done
      for d in $(devs); do busctl --timeout=15 call org.bluez "$d" org.bluez.Device1 Connect && return 0; done
      return 1
    }
    bt_disconnect() {
      for d in $(devs); do
        if connected "$d"; then busctl call org.bluez "$d" org.bluez.Device1 Disconnect || true; fi
      done
    }

    use() {
      pactl set-default-sink "$1"
      pactl list short sink-inputs | awk '{ print $1 }' | while read -r id; do
        pactl move-sink-input "$id" "$1" || true
      done
      notify-send -a deck-audio "Sortie audio" "$2"
    }

    case "''${1:-}" in
      casque)
        bt_connect >/dev/null || true
        card=bluez_card.''${mac//:/_}
        sink=""
        for _ in $(seq 20); do
          pactl set-card-profile "$card" a2dp-sink 2>/dev/null || true
          sink=$(sink_of "bluez_output.''${mac//:/_}")
          [ -n "$sink" ] && break
          sleep 0.5
        done
        if [ -z "$sink" ]; then
          notify-send -a deck-audio "dafcans" "Casque introuvable : allumé et à portée ?"
          exit 1
        fi
        use "$sink" "dafcans"
        ;;
      ecran) use "$lg" "Haut-parleurs de l'écran LG" ;;
      deconnecter)
        bt_disconnect >/dev/null
        use "$lg" "dafcans déconnecté, son sur l'écran LG"
        ;;
      *)
        echo "usage: deck-audio casque|ecran|deconnecter" >&2
        exit 2
        ;;
    esac
  '';
}
