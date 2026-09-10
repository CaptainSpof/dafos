# dafbox

Desktop/workstation. AMD CPU + GPU (Navi 31 / RX 7900), Niri with autologin and
the DMS greeter, gaming archetype, sunshine, syncthing.

## Audio: pin the LG, not the M27Q

The Navi 31 exposes several HDMI/DP audio profiles but only one can be active at
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
