# DMS (dank-material-shell)

## Theming and light/dark

DMS owns light/dark directly rather than following the portal's appearance
signal. The KDE Settings xdg-desktop-portal backend cannot recompute light/dark
outside a full Plasma session, so under Niri it always reports "light". Only
`org.freedesktop.impl.portal.Settings` is routed to the `gtk` backend; the rest
of the portal stays on KDE. The chain lives across [default.nix](default.nix)
and [../niri/AGENTS.md](../niri/AGENTS.md).

Matugen template rendering is gated by `runDmsMatugenTemplates` plus per-app
`matugenTemplate*` options. The older `gtkThemingEnabled` / `qtThemingEnabled`
switches are dead — do not reintroduce them. Watch for two modules writing the
same target (qt6ct and wezterm collided once).

GTK, the qt6ct palette and the KDE colour schemes are rendered from _our_
templates ([colors.nix](colors.nix)), with DMS's equivalents switched off in
`matugenTemplateOverrides`. Those gates are patched into the running
`settings.json` on activation, because that file is seeded only once — a setting
added to `dmsSettings` alone never reaches an existing install.

**A background a widget style may fill behind arbitrary text — selection, hover,
focus — must sit on the same lightness side as the surface.** A style does not
only use the paired on-colour: Qt's Inactive group (Dolphin's Places sidebar,
once the file view has focus) draws with its own text role, and Darkly fills a
hovered row with `DecorationHover` without touching the text. Under
`scheme-fidelity`, `primary`, `primary_container` and `tertiary_container` do
_not_ flip with light/dark — they stay faithful to the wallpaper — so a fill
built from them is a near-white pill under near-white text in dark mode. Use
`secondary_container`, `surface_container*` or `inverse_primary` for fills;
[colors.nix](colors.nix) carries the reasoning in full.

## The "Games" folder is faked, in two halves

DMS has no concept of a folder in the app drawer.
`dafos.desktop.dms.gamesFolder` fakes one with two pieces that must agree on
what counts as a game:

1. `dms-games-sync` ([games-sync.py](games-sync.py), a user service plus a path
   unit on `~/.local/share/applications`) classifies desktop entries, writes
   `~/.local/state/dms-games/games.json`, and pushes those ids into DMS's
   `session.json` `hiddenApps`.
2. The `gamesFolder` launcher plugin in [plugins/games](plugins/games) reads
   that JSON back.

**The classification rule lives only in the script.** Change it there, not in
the plugin.

Two consequences worth knowing before "simplifying" this:

- Hiding an app also drops it from DMS's built-in _Games_ category chip, since
  both go through `getVisibleApplications`. That is why the plugin enumerates
  `DesktopEntries` instead of reusing that filter.
- `NoDisplay=true` is the wrong lever: quickshell removes NoDisplay entries from
  `DesktopEntries.applications` entirely.

Plugin enable-state is seeded once into the runtime-owned
`plugin_settings.json`. Turning the option off runs `dms-games-sync --unhide`
from activation to put the games back.

## Plugin edits look like no-ops

Qt caches plugin components. After editing a plugin, run `plugins reload` —
otherwise the old component keeps serving and the edit appears to have done
nothing.
