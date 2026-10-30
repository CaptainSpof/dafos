# Glove80

ZMK firmware for the MoErgo Glove80, giving it the same behaviour as the
laptop/desktop keyboards under kanata. Nothing here is evaluated by the flake.

- **The keymap mirrors kanata.** `glove80.keymap` ports
  `modules/nixos/system/kanata` (base_lt_hrm, navigation_vim,
  accent, switcher + their aliases); each layer names the `.kbd` it copies. A
  change to one belongs in the other.
- **The thumbs deliberately differ** from the laptop: Space/Shift + Tab on the
  left, Bspc/Shift + Enter/Nav on the right, and no Symbols layer (the AltGr
  thumb gives the same symbols). Do not port those back to kanata.
- **Bindings are physical keys**, like kanata's: the host layout stays
  `fr(ergol)` and turns them into Ergo-L. On a machine without that layout the
  Glove80 types QWERTY.
- **kanata must keep ignoring the Glove80** (`"MoErgo Glove80 Left Keyboard"` in
  `dafos.system.kanata.excludedDevices`), or every mod-tap runs twice.
- **The ★ accent combos** are the same macros as `defalias/ergol_accent.kbd`;
  read that file's comment before touching them (letter, not Level5 position;
  Pause = Multi_key needs the `compose:paus` xkb option).

## Build and flash

```bash
nix-build glove80          # result/glove80.uf2, both halves in one file
```

The source is MoErgo's fork (`moergo-sc/zmk`), pinned by tag in `default.nix`;
it builds with its own pinned nixpkgs. Bump the tag and the `sha256`
(`nix-prefetch-url --unpack <tarball url>`) together.

Flash each half, one at a time, over USB:

1. Plug the half in, hold Magic (bottom-left key of the left half) and tap the
   outer home-row key of that half (Esc position on the left, `'` on the right):
   it reboots as a `GLV80LHBOOT` / `GLV80RHBOOT` drive.
2. Copy `result/glove80.uf2` onto the drive; it reboots on its own.
