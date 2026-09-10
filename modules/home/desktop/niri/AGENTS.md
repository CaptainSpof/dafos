# niri

## Config include precedence

DMS's `dms/*.kdl` includes land _after_ niri-flake's generated `hm.kdl`, so they
win. Anything that has to override a niri-flake value — ring widths, colours —
belongs in a last-included matugen template, not in the Home Manager options.

## Portal

`org.freedesktop.impl.portal.Settings` is routed to the `gtk` backend because
the KDE backend cannot report light/dark correctly outside a Plasma session. See
[../dms/AGENTS.md](../dms/AGENTS.md) for the full chain.

The ScreenCast portal must be **wlr** (SHM), not gnome (DMABUF-only): Steam's
bundled libgbm cannot DMA-BUF on mesa 25.1+, which shows up as a black screen in
Remote Play. After switching backends, clear the stale screencast permission
entry from the portal permission store or the old choice sticks.

## Service discovery

Avahi runs with IPv6 disabled. Rotating IPv6 privacy addresses caused an endless
`dafbox-2`, `dafbox-3`, … hostname-conflict rename loop, which left Sunshine's
`_nvstream` record permanently undiscoverable. Restart sunshine after restarting
avahi.
