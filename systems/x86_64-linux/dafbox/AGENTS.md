# dafbox

Desktop/workstation. AMD CPU + GPU (Navi 32 / RX 7800 XT), Niri with autologin
and the DMS greeter, gaming archetype, sunshine, syncthing.

## Audio: pin the LG, not the M27Q

The Navi 32 exposes several HDMI/DP audio profiles but only one can be active at
a time. WirePlumber defaults to the higher-priority M27Q port, which has no
speakers — only the LG monitor does. The fix is declarative: the
`99-pin-lg-audio` ALSA rule in [default.nix](default.nix) pins `device.profile`
to `output:hdmi-stereo-extra1` on `alsa_card.pci-0000_03_00.1` and renames the
sink.

If sound disappears after a GPU or WirePlumber bump, check whether the card or
port names moved before changing anything else.

## Fan control

`dafos.hardware.sensors` only turns CoolerControl on; it does not give it
anything to control. The board's NCT6799D Super-I/O owns CPU_FAN, CHA_FAN and
AIO_PUMP and has no driver unless `nct6775` is in `boot.kernelModules` — it is
loaded explicitly in [hardware.nix](hardware.nix). Without it, coolercontrold
detects the chip, logs `status: skipped_no_modprobe`, and the GPU's `pwm1` is
the only writable PWM on the box while the CPU curve stays stuck in BIOS Q-Fan.

Board-specific facts, all verified on hardware:

- **CPU_FAN is `fan2`/`pwm2`**, not `fan1`.
- `fan6`/`fan7` report 82% with no tach — unpopulated pump headers.
- asus-ec-sensors' `Water_In`/`Water_Out` are phantom readings. dafbox is
  air-cooled.
- No `acpi_enforce_resources=lax` is needed despite ACPI reserving
  `io 0x0290-0x029f`, and the ASUS EC does not fight a manual `pwm2_enable=1`,
  so no BIOS change is required.

Curves live in `/var/lib/coolercontrol` and are **stateful**.
`programs.coolercontrol.enable` is the only NixOS option there is, so only the
driver half is declarative.

## Disks

Runs the declarative disko btrfs layout in [disko.nix](disko.nix), imported from
`default.nix`: ESP + 36G swap (hibernate-capable, >30GiB RAM) + 100G btrfs `/`
on the Sabrent NVMe, and a `/home` btrfs pool (`data=single`, `metadata=raid1`)
spanning the rest of the Sabrent plus the whole 970 EVO. No data redundancy —
either drive dying loses `/home`.

`hardware.nix` must not re-declare `/`, `/home`, `/boot` or swap; disko
generates those. [DISK-POOL-PLAN.md](DISK-POOL-PLAN.md) and
[DISK-DESTRUCTIVE-RUNBOOK.md](DISK-DESTRUCTIVE-RUNBOOK.md) keep the rationale
and the exact commands, including host-key preservation, for if the layout is
ever revisited.

## Ethernet stuck at ~100 Mbit until the cable is replugged

Symptom (2026-11-21): `eno1` (RTL8125 rev 05, `r8169`) reports 1000 Mb/s full
but real throughput is ~10.5 MB/s in both directions, to the LAN and to the
internet; only a physical unplug/replug restores ~120 MB/s.

Ruled out with evidence, so do not retry them: ASPM (all L1 states 0), PCIe AER
(all 0), EEE (off changed nothing), PHY/MAC speed (MII and `PHYstatus` both say
1000), `ethtool -r`, `ip link set eno1 down/up`, CPU, TCP congestion control,
CRC/FIFO errors (0).

What the data says: with flow control on, `rx_pause_frames` climbs while the NIC
sends (the router pauses dafbox). With flow control off the NIC emits 123 MB/s
of UDP, but the peer receives only ~12 MB/s: the loss is past the NIC, on the
router port or the link to it, and a software link bounce does not clear it.
Root cause unproven; no declarative fix was made.

Diagnose without root (ethtool: `nix build nixpkgs#ethtool`; use LAN IPs, since
`dafoltop` resolves to its tailscale address):

- `ethtool -I --show-pause eno1`: watch `rx_pause_frames` while sending.
- UDP blast to `192.168.0.10:9` for 4 s, comparing dafbox `tx_bytes` with the
  peer's `rx_bytes` delta.

Next steps if it recurs: replug into another router port, or put a small switch
between dafbox and the router.
