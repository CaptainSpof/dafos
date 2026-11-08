#!/usr/bin/env python3
"""nexus-mod-check: report which Nexus Mods downloads have a newer file online.

Works for any game: point it at a folder of downloaded mod archives (the ones
named by Nexus / the nxm handler) and tell it the Nexus game domain
(the slug in nexusmods.com/<domain>/mods/...).

    nexus-mod-check ~/Downloads/mods/TCG --game tcgcardshopsimulator
    nexus-mod-check ~/Downloads/mods/cyberpunk          # uses <dir>/.nexus-game
    nexus-mod-check DIR --game DOMAIN --save            # remember the domain
    nexus-mod-check DIR --all                           # also list up-to-date mods
    nexus-mod-check DIR --include-optional              # optional files count too

How it works
  * Parses each archive name for (mod id, upload date). Two Nexus naming
    schemes are understood:
      "Name 1660 1.0.3 2026-10-28T15-56Z hash.zip"   (browser download)
      "Name-2-5-4-23-2-1726589034.zip"               (mod manager / nxm)
  * Per mod id, the newest local file is "installed".
  * Asks the public Nexus GraphQL API (no key needed) for the mod's files and
    flags the mod when a MAIN/UPDATE file is newer than the local one.
  * Exit status: 0 all current, 1 updates available, 2 error.

Limits: it only sees archives in the folder, not what is actually deployed, and
archives without a Nexus-style name are listed as "unparsed".
"""
import argparse
import datetime as dt
import json
import re
import sys
import urllib.request
from pathlib import Path

API = "https://api.nexusmods.com/v2/graphql"
EXT = (".zip", ".7z", ".rar", ".tar.gz")
DAY = 86400
SLACK = 150  # seconds; browser-style names only keep the minute
CURRENT_CATEGORIES = {"MAIN", "UPDATE"}

# "Name 1660 1.0.3 2026-10-28T15-56Z hash.zip"
RE_BROWSER = re.compile(
    r"^(?P<name>.+?) (?P<id>\d+) (?P<ver>\S+) "
    r"(?P<date>\d{4}-\d\d-\d\dT\d\d-\d\dZ) \S+\.\w+$"
)
# "Name-2-5-4-23-2-1726589034.zip" (modId-version-epoch)
RE_MANAGER = re.compile(
    r"^(?P<name>.+?)-(?P<id>\d+)-(?P<ver>\d+(?:-\d+)*)-(?P<epoch>\d{9,10})\.\w+$"
)


def parse(fname):
    m = RE_BROWSER.match(fname)
    if m:
        t = dt.datetime.strptime(m["date"], "%Y-%m-%dT%H-%MZ").replace(tzinfo=dt.timezone.utc)
        return m["name"], int(m["id"]), m["ver"], int(t.timestamp())
    m = RE_MANAGER.match(fname)
    if m:
        return m["name"], int(m["id"]), m["ver"].replace("-", "."), int(m["epoch"])
    return None


def gql(query):
    req = urllib.request.Request(
        API,
        json.dumps({"query": query}).encode(),
        {"content-type": "application/json", "user-agent": "nexus-mod-check"},
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def game_id(domain):
    d = gql('{game(domainName:%s){id}}' % json.dumps(domain))
    g = (d.get("data") or {}).get("game")
    if not g:
        sys.exit(f"unknown Nexus game domain: {domain}")
    return g["id"]


def latest_files(gid, mod_ids, include_optional):
    cats = CURRENT_CATEGORIES | ({"OPTIONAL", "MISCELLANEOUS"} if include_optional else set())
    out = {}
    ids = sorted(mod_ids)
    for i in range(0, len(ids), 20):
        chunk = ids[i : i + 20]
        q = "{" + " ".join(
            f"m{n}:modFiles(modId:{n},gameId:{gid}){{name version date category}}" for n in chunk
        ) + "}"
        d = gql(q)
        data = d.get("data") or {}
        errs = {e["path"][0] for e in d.get("errors", []) if e.get("path")}
        for n in chunk:
            files = data.get(f"m{n}")
            if files is None or f"m{n}" in errs:
                out[n] = None  # removed / hidden
            else:
                out[n] = [f for f in files if f["category"] in cats]
    return out


def fmt(ts):
    return dt.datetime.fromtimestamp(ts, dt.timezone.utc).strftime("%Y-%m-%d")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("dir", type=Path, help="folder of downloaded mod archives")
    ap.add_argument("--game", help="Nexus game domain (e.g. cyberpunk2077)")
    ap.add_argument("--save", action="store_true", help="write the domain to <dir>/.nexus-game")
    ap.add_argument("--all", action="store_true", help="also list up-to-date mods")
    ap.add_argument("--include-optional", action="store_true", help="count optional/misc files as updates")
    a = ap.parse_args()

    if not a.dir.is_dir():
        sys.exit(f"not a directory: {a.dir}")
    marker = a.dir / ".nexus-game"
    domain = a.game or (marker.read_text().strip() if marker.exists() else None)
    if not domain:
        sys.exit("no game: pass --game DOMAIN (add --save to remember it)")
    if a.save and a.game:
        marker.write_text(domain + "\n")

    installed, unparsed = {}, []
    for f in sorted(a.dir.iterdir()):
        if not f.is_file() or not f.name.lower().endswith(EXT):
            continue
        p = parse(f.name)
        if not p:
            unparsed.append(f.name)
            continue
        name, mid, ver, ts = p
        if mid not in installed or ts > installed[mid][2]:
            installed[mid] = (name, ver, ts)

    try:
        gid = game_id(domain)
        latest = latest_files(gid, installed, a.include_optional)
    except Exception as e:  # network / API
        sys.exit(f"API error: {e}")

    outdated, gone, current = [], [], []
    for mid, (name, ver, ts) in sorted(installed.items(), key=lambda kv: kv[1][0].lower()):
        lf = latest[mid]
        if lf is None:
            gone.append((mid, name))
        else:
            # Newer file, ignoring same-version files uploaded the same day
            # (multi-file mods: the local archive is just a sibling file).
            newer = [f for f in lf if f["date"] > ts + SLACK
                     and (f["version"] != ver or f["date"] > ts + DAY)]
            if newer:
                outdated.append((mid, name, ver, ts, max(newer, key=lambda f: f["date"])))
                continue
            current.append((mid, name, ver))

    base = f"https://www.nexusmods.com/{domain}/mods"
    print(f"{domain}: {len(installed)} mods, {len(outdated)} outdated, {len(gone)} not found, "
          f"{len(unparsed)} unparsed archives")
    for mid, name, ver, ts, lf in outdated:
        print(f"  UPDATE  {name}  {ver} ({fmt(ts)}) -> {lf['version']} ({fmt(lf['date'])})  {base}/{mid}?tab=files")
    for mid, name in gone:
        print(f"  GONE    {name}  {base}/{mid}  (hidden, removed or no public files)")
    if a.all:
        for mid, name, ver in current:
            print(f"  ok      {name}  {ver}")
    if unparsed and a.all:
        for n in unparsed:
            print(f"  ?       {n}")
    sys.exit(1 if outdated else 0)


if __name__ == "__main__":
    main()
