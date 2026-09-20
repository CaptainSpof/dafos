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

## settings.json is extracted, not authored

DMS persists only values that differ from its own defaults, so a running
install's `~/.config/DankMaterialShell/settings.json` _is_ the delta.
[settings.json](settings.json) here is that file, lifted verbatim minus the keys
[default.nix](default.nix) supplies (`barConfigs`, `controlCenterWidgets`,
`dockConfigs`, the `enforcedSettings` keys and the commented scalar block).

Re-extract rather than hand-edit, and re-baseline an existing install with:

```bash
rm ~/.config/DankMaterialShell/settings.json && home-manager switch
```

DMS renames and regroups settings between versions — `use24HourClock` became
`clockFormat`, the thirteen top-level `dock*` settings became `dockConfigs`,
control-center `width` percentages became a `w`/`h` grid, and
`workspaceFollowFocus` moved inside the `workspaceSwitcher` widget. Check a key
against `Common/settings/{SettingsSpec,SessionSpec}.js` (and their
`DankCommon/.../Shared*` counterparts) in the `dms-shell` store path before
trusting that it still exists; a key DMS no longer knows is dropped silently on
its next save.

**A setting that only lives in the seed never reaches an existing install** —
the file is written once and owned by DMS afterwards. Anything that must hold
goes in `enforcedSettings`, which the `dmsEnforcedSettings` activation patches
back on every switch. `calendarBackend` is there because a schema migration had
already reset it to `auto`, silently emptying the dash's calendar card.

## Bars: the module owns the vocabulary, hosts own the layout

dafbox and daftop do not share a bar layout, and **this module holds no host
names**. [bar.nix](bar.nix) publishes building blocks — `mainBar`, `sideBar`,
`controlCenterWidgets`, `dockConfigs` — as `dafos.desktop.dms.bar.parts`. Each
host assembles its own `bar.configs` from those in its
`homes/daf@<host>/default.nix`, which is also where the display names and panel
models live.

`sideBar` deliberately ships without `screenPreferences`: which panel it belongs
on is precisely what the hosts disagree about. When a second field starts to
differ, drop it from the piece the same way rather than adding a parameter or a
per-host file here.

Where a piece cannot stay neutral — a widget list, say — it takes the
**leanest** host's shape, so a host that wants more adds rather than subtracts.
`sideBar` is daftop's sparse right-hand bar for that reason, and dafbox layers
its busier edge (wallpaper picker, KDE Connect, clight, tailscale, keyboard
layout, clipboard, VPN) on top in its own file. Re-extract that piece from
daftop when the two drift again.

The default `bar.configs` is the main bar alone, so a host that says nothing
still gets something sane.

A bar _style_ is vocabulary, not host shape, so it belongs here rather than in a
host file: `islandStyle` is an overlay a host merges over a bar
(`mainBar // islandStyle`) to collapse it into DMS's hover-expanding pill. It
carries no id, geometry or widgets of its own, and lists only the island keys
that differ from DMS's `islandDefaults` (`Common/SettingsData.qml`). daftop's
top bar is built this way; dafbox's is not.
