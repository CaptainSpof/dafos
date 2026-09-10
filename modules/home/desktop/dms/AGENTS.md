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
