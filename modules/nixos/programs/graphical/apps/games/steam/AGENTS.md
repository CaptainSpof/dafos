# Steam

## gamescope launch options on Niri

Per-game launch options must be exactly this shape:

```
env MESA_VK_WSI_PRESENT_MODE=mailbox gamescope <flags> -- env -u MESA_VK_WSI_PRESENT_MODE gamemoderun %command%
```

Without the mailbox present mode, gamescope's first present to its output window
deadlocks in Mesa's Wayland FIFO WSI: the game runs with sound and no window.
Plasma is unaffected, so this only reproduces under Niri. The inner `env -u`
puts the game itself back on the default present mode.

Never use `-e` as a per-game wrapper.

## FHS sandbox

gamescope and gamemode are baked into Steam's FHS sandbox through
`extraPkgs`/`extraLibraries` in [default.nix](default.nix). The sandbox has a
**private `/tmp`**, so any debug probe must write to `$HOME` to be readable from
outside.
