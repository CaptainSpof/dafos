# ESPHome devices

Firmware configs for DIY ESPHome devices, built on dafbox and flashed by hand.
Nothing here is evaluated by the flake. (The Everything Presence sensors run
vendor firmware; see
`modules/nixos/services/everything-presence-zone-configurator/AGENTS.md`.)

## Build

Always go through `./run`: it copies the config to
`$XDG_CACHE_HOME/dafos-esphome/` (`~/.local/cache` here), decrypts
`secrets/dafoltop/esphome.yaml` there as the `secrets.yaml` ESPHome expects, and
runs the flake-pinned `esphome`. The decrypted secrets and the `.esphome/` build
tree must never land in the repo.

```bash
esphome/run config minuteur                            # validate
esphome/run compile minuteur                           # build (first one ~15 min)
esphome/run upload minuteur --device minuteur.local    # OTA, after the first flash
esphome/run logs minuteur --device minuteur.local
```

`compile` catches what `config` does not: every lambda is C++ and only fails at
build time.

## minuteur — Waveshare ESP32-S3-Knob-Touch-LCD-1.8

Kitchen countdown timer. The device owns the countdown; Home Assistant only
mirrors it to dafphone through `minuteur-automation.yaml`, a UI automation whose
source of truth is this file (push it with the config API, as with the other UI
automations). `minuteur-battery-automation.yaml` is the low-battery alert, kept
separate because the timer automation runs in `mode: restart`.

- **The first flash is over USB** (16 MB layout differs from stock, OTA can't
  change it). The port is `root:dialout`, so flash the factory image with
  `sudo nix run nixpkgs#esptool -- --port /dev/ttyACM1 write-flash 0 $XDG_CACHE_HOME/dafos-esphome/.esphome/build/minuteur/build/firmware.factory.bin`.
- **The USB-C cable orientation picks the chip**: one way is the ESP32-S3, the
  other the auxiliary ESP32. `esptool flash-id` must say ESP32-S3.
- **Stock firmware backup**: `~/Documents/waveshare-knob/stock-firmware-2.bin`
  (full 16 MB, verified against a second read; only `nvs` differed). Restore
  with `write-flash 0` on that file.
- **Wi-Fi is not in the config**: on first boot the device opens the `Minuteur`
  access point (password `minuteur_ap_password` in the secrets file) and the
  network is picked from its captive portal. **Type the SSID in by hand**: the
  first provisioning saved an empty SSID, connected once from memory, then could
  never reconnect ("No networks found" means no _matching_ network, and the boot
  log showed `Loaded settings:` with nothing after it). Check the boot log for
  `Loaded settings: DafWifi` after provisioning.
- **The board's second chip jams the S3's radio.** Waveshare's stock firmware on
  the ESP32-U4WDH keeps its Wi-Fi/BT busy: the S3's scans mostly found nothing
  ("No networks found", "Probe Request Unsuccessful", even next to the box) and
  timers never reached HA. `minuteur-aux.yaml` puts that chip in deep sleep for
  good; flash it over the CH341 port (`/dev/ttyUSB0`, cable flipped) at
  `--baud 460800` (921600 corrupts). Stock backup:
  `~/Documents/waveshare-knob/aux-stock-firmware.bin` (two identical reads).
  Before blaming distance, put that chip in its bootloader
  (`esptool --after no-reset flash-id`) and compare the S3's scans.
- **The box's BSS refuses the timer** ("Not Associated") even at −70 dBm; it
  connects through the repeater after two failed attempts on every wake.
- **Serial logs without sudo**: `sudo setfacl -m u:daf:rw /dev/ttyACM1` once
  (gone on replug), then read with pyserial. Opening the port resets the chip
  even with DTR/RTS low, which conveniently yields a full boot log; a plain
  `cat` loses everything after the reset.
- **The knob is not quadrature**: a detent holds one channel low, A (GPIO8)
  clockwise, B (GPIO7) anticlockwise; there is no push contact. It is read by
  edge interrupts in `minuteur/knob.h`, whose header records the measured pulse
  shapes and the filter they imply. The polled `rotary_encoder_custom` it
  replaced missed most detents of a fast spin (an LVGL redraw outlasts a pulse),
  so knob inertia never kicked in.
- **The opposite channel glitches for 2–300 µs after every detent**, often read
  back high by the handler: a naive "low for ≥ X" filter turns them into
  backwards detents. `minuteur/knob_probe.h` is the edge recorder that found
  this; reuse it before touching the filter.
- **Never install the GPIO ISR service yourself**: the touchscreen attaches its
  interrupt late in setup, and ESPHome's `attach_interrupt()` gives up without
  attaching when the service already exists (dead touchscreen). Arm the knob
  after boot (`on_boot` -100, after the delay).
- **The knob can rest half-way with a channel held low** (seen at boot and for
  seconds after a spin). `go_to_sleep` leaves such a pin out of the ext1 mask
  instead of refusing to sleep.
- **No IMU on this board**, so orientation is a fixed `rotation: 180` on
  `lvgl:`.
- **The DRV2605 NAKs register reads**, so the haptics component fails setup; the
  config writes the registers directly over I²C.
- **LVGL text lambdas return `const char*` from a multi-statement body** (static
  buffer): a one-line lambda returning `std::string` fails to compile on ESPHome
  2026.7+.
- **Deep sleep when idle** (`sleep_after`, 1 min): wakes on ext1 `ANY_LOW` from
  the knob (GPIO7/8) or the touch interrupt (GPIO9); a wake is a reboot. It only
  sleeps once HA has been connected 20 s straight (`api_up_s`): sleeping the
  moment HA connected left HA with `unknown` states. With `deep_sleep` present
  HA keeps the last states while asleep instead of `unavailable`.
- **A sleeping device has no USB port and no OTA**: turn the knob, then flash
  within the minute; for OTA, switch off `Veille automatique` in HA first. On
  USB, `journalctl -k` shows each sleep (USB disconnect) and wake.
- **Pads held across sleep** (backlight GPIO47 low, touch reset GPIO10 high) and
  the wake pins left as RTC IO must be released at boot, before the display,
  touch and knob set up (`on_boot` priority 1000).
- **Battery**: GPIO1 behind a 2:1 divider; on USB it reads ~4.3 V (charging), so
  100 % there means "plugged in". The board's second chip (the auxiliary ESP32,
  still on stock firmware) draws power that no setting here reaches.

Pinout and the board quirks come from
[tomereli/coffee-knob](https://github.com/tomereli/coffee-knob) and
[KrX3D/WaveShare-Knob-Esp32S3](https://github.com/KrX3D/WaveShare-Knob-Esp32S3).
