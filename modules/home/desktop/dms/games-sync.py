"""Sync the DMS "Games" launcher folder.

Scans XDG desktop entries for games, writes the list that the gamesFolder DMS
plugin reads, and hides those same entries from the launcher's flat app list by
adding them to DankMaterialShell's session.json `hiddenApps`. Result: games live
in one folder instead of being sprinkled through the app drawer, while a normal
search still finds them (DMS searches every launcher plugin in "all" mode).

The classification rule lives here and nowhere else — the plugin just reads
games.json.

Configuration comes from the environment (all optional):
  DMS_GAMES_STATE_DIR      where games.json / managed.json are written
  DMS_SESSION_FILE         DankMaterialShell session.json
  DMS_GAMES_INCLUDE_IDS    desktop ids to force into the folder
  DMS_GAMES_EXCLUDE_IDS    extra desktop ids to keep out of it
  DMS_GAMES_EXCLUDE_CATS   extra categories that disqualify an entry
  DMS_BIN / SYSTEMCTL_BIN  binaries used to nudge a running DMS

Run with --unhide to undo the hiding (used when the feature is turned off).
"""

import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

DESKTOP_GROUP = "[Desktop Entry]"

# Tools that ship Categories=Game but are launchers/managers, not games. The
# category filter below catches most of them (Steam is Network;FileTransfer,
# Lutris is PackageManager, ProtonUp-Qt is Utility, Ryujinx is Emulator); these
# declare Game and little else, so they need naming.
DEFAULT_EXCLUDE_IDS = (
    "com.heroicgameslauncher.hgl",
    "com.moonlight_stream.Moonlight",
    "com.usebottles.bottles",
    "com.vysp3r.ProtonPlus",
    "heroic",
    "steamtinkerlaunch",
)

DEFAULT_EXCLUDE_CATS = (
    "Development",
    "Emulator",
    "FileTransfer",
    "Network",
    "PackageManager",
    "Settings",
    "System",
    "Utility",
)


def env_list(name):
    raw = os.environ.get(name, "").strip()
    if not raw:
        return []
    return [part for part in re.split(r"[,\s]+", raw) if part]


def env_path(name, default):
    raw = os.environ.get(name, "").strip()
    return Path(raw) if raw else Path(default)


def state_home():
    return Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state")


def application_dirs():
    """Every applications/ dir, in XDG lookup order (first match wins)."""
    data_home = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share")
    dirs = [data_home / "applications"]
    raw = os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
    dirs.extend(Path(d) / "applications" for d in raw.split(":") if d)
    return dirs


def parse_entry(path):
    """Return the [Desktop Entry] group as a dict, or None."""
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None

    data = {}
    in_group = False
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("["):
            if in_group:
                break
            in_group = line == DESKTOP_GROUP
            continue
        if not in_group or "=" not in line:
            continue
        key, _, value = line.partition("=")
        data.setdefault(key.strip(), value.strip())
    return data or None


def scan_entries():
    """desktop id -> parsed entry, using the same id rule as quickshell."""
    entries = {}
    for base in application_dirs():
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*.desktop")):
            try:
                rel = path.relative_to(base)
            except ValueError:
                continue
            entry_id = str(rel.with_suffix("")).replace("/", "-")
            if entry_id in entries:
                continue
            data = parse_entry(path)
            if data:
                entries[entry_id] = data
    return entries


def truthy(value):
    return (value or "").strip().lower() == "true"


def categories(data):
    return [c for c in (data.get("Categories") or "").split(";") if c]


def is_game(entry_id, data, include_ids, exclude_ids, exclude_cats):
    if entry_id in exclude_ids:
        return False
    if entry_id in include_ids:
        return True
    if (data.get("Type") or "Application") != "Application":
        return False
    if truthy(data.get("NoDisplay")) or truthy(data.get("Hidden")):
        return False
    cats = categories(data)
    if "Game" not in cats:
        return False
    return not (set(cats) & exclude_cats)


def source_label(exec_line):
    low = (exec_line or "").lower()
    if "steam://rungameid/" in low:
        return "Steam"
    if "lutris:rungameid/" in low or re.search(r"\blutris\b", low):
        return "Lutris"
    if "heroic://" in low:
        return "Heroic"
    if "bottles" in low:
        return "Bottles"
    return ""


def collect_games():
    # The environment adds to the defaults rather than replacing them, so a host
    # only has to name what is peculiar to it.
    include_ids = set(env_list("DMS_GAMES_INCLUDE_IDS"))
    exclude_ids = set(DEFAULT_EXCLUDE_IDS) | set(env_list("DMS_GAMES_EXCLUDE_IDS"))
    exclude_cats = set(DEFAULT_EXCLUDE_CATS) | set(env_list("DMS_GAMES_EXCLUDE_CATS"))

    games = []
    for entry_id, data in scan_entries().items():
        if not is_game(entry_id, data, include_ids, exclude_ids, exclude_cats):
            continue
        exec_line = data.get("Exec") or ""
        games.append(
            {
                "id": entry_id,
                "name": data.get("Name") or entry_id,
                "icon": data.get("Icon") or "input-gaming",
                "comment": source_label(exec_line) or data.get("Comment") or "",
                "exec": exec_line,
            }
        )
    games.sort(key=lambda game: game["name"].lower())
    return games


def read_json(path, fallback):
    try:
        with path.open(encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return fallback


def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    with tmp.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    os.replace(tmp, path)


def read_managed(managed_path):
    stored = read_json(managed_path, {})
    if not isinstance(stored, dict):
        return set()
    ids = stored.get("ids")
    return set(ids) if isinstance(ids, list) else set()


def update_hidden_apps(session_path, managed_path, game_ids):
    """Set hiddenApps to (whatever the user hid) + (our games)."""
    session = read_json(session_path, {})
    if not isinstance(session, dict):
        session = {}
    previously_managed = read_managed(managed_path)

    current = session.get("hiddenApps") or []
    if not isinstance(current, list):
        current = []

    # Drop what we hid last time, keep manual hides, then add today's games.
    hidden = [app for app in current if app not in previously_managed]
    for game_id in game_ids:
        if game_id not in hidden:
            hidden.append(game_id)

    write_json(managed_path, {"ids": sorted(game_ids)})

    if hidden == current:
        return False
    session["hiddenApps"] = hidden
    write_json(session_path, session)
    return True


def unhide(session_path, managed_path):
    """Drop our hides from session.json. Returns the ids we had hidden."""
    managed = read_managed(managed_path)
    managed_path.unlink(missing_ok=True)
    if not managed:
        return set()

    session = read_json(session_path, {})
    if not isinstance(session, dict):
        return set()
    current = session.get("hiddenApps") or []
    hidden = [app for app in current if app not in managed]
    if hidden == current:
        return set()
    session["hiddenApps"] = hidden
    write_json(session_path, session)
    return managed


def dms_hidden_apps(dms_bin):
    """What the running DMS has in memory, or None if it isn't up."""
    try:
        result = subprocess.run(
            [dms_bin, "ipc", "call", "settings", "dumpSession"],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if result.returncode != 0:
        return None
    start = result.stdout.find("{")
    if start == -1:
        return None
    try:
        session = json.loads(result.stdout[start:])
    except ValueError:
        return None
    hidden = session.get("hiddenApps")
    return set(hidden) if isinstance(hidden, list) else set()


def ensure_dms_reloaded(
    dms_bin, systemctl_bin, present=frozenset(), absent=frozenset()
):
    """DMS watches session.json, so it normally reloads on its own.

    If it hasn't after a moment (stale watch, or our write raced one of its own
    saves), restart it rather than leave in-memory state that would overwrite
    the file on the next save.
    """

    def in_sync():
        live = dms_hidden_apps(dms_bin)
        if live is None:
            return None
        return present <= live and not (absent & live)

    state = in_sync()
    if state is None:
        return "not running"
    if state:
        return "picked up"

    time.sleep(2)
    if in_sync():
        return "picked up"

    subprocess.run([systemctl_bin, "--user", "restart", "dms.service"], check=False)
    return "restarted dms"


def main():
    state_dir = env_path("DMS_GAMES_STATE_DIR", state_home() / "dms-games")
    session_path = env_path(
        "DMS_SESSION_FILE", state_home() / "DankMaterialShell/session.json"
    )
    managed_path = state_dir / "managed.json"
    games_path = state_dir / "games.json"
    dms_bin = os.environ.get("DMS_BIN", "dms")
    systemctl_bin = os.environ.get("SYSTEMCTL_BIN", "systemctl")

    if "--unhide" in sys.argv[1:]:
        restored = unhide(session_path, managed_path)
        games_path.unlink(missing_ok=True)
        if not restored:
            print("games folder off: nothing to unhide")
            return 0
        status = ensure_dms_reloaded(dms_bin, systemctl_bin, absent=restored)
        print(f"games folder off: unhid {len(restored)} game(s), {status}")
        return 0

    games = collect_games()
    game_ids = [game["id"] for game in games]
    write_json(games_path, {"generated": int(time.time()), "games": games})

    if not update_hidden_apps(session_path, managed_path, game_ids):
        print(f"{len(games)} game(s), hidden list unchanged")
        return 0

    status = ensure_dms_reloaded(dms_bin, systemctl_bin, present=set(game_ids))
    print(f"{len(games)} game(s), {status}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
