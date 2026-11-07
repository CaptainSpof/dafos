# nxm:// handler for Nexus Mods "Mod manager download" links, for a free
# account: the button's one-time key is exchanged for a download URL through
# the official API (the same call a mod manager makes), then the file lands in
# ~/Downloads/mods/<dir> with no browser dialog. Needs the personal API key in
# ~/.config/nexus-apikey (never logged or printed). Log: ~/.local/state/nxm-handler.log
#
# Takes over x-scheme-handler/nxm from nexusmods-app, which registers itself
# too.
_: {
  flake.modules.homeManager.nxm-handler =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.dafos.programs.nxm-handler;

      handler =
        pkgs.writers.writePython3Bin "nxm-handler"
          {
            flakeIgnore = [
              "E501"
              "E231"
            ];
          }
          ''
            import json
            import os
            import re
            import subprocess
            import sys
            import time
            import urllib.parse
            import urllib.request
            from pathlib import Path

            HOME = Path.home()
            API = os.environ.get("NXM_API_BASE", "https://api.nexusmods.com")
            DRY = os.environ.get("NXM_DRY_RUN") == "1"
            ROOT = Path(os.environ.get("NXM_DEST", HOME / "Downloads" / "mods"))
            KEYFILE = HOME / ".config" / "nexus-apikey"
            LOG = HOME / ".local" / "state" / "nxm-handler.log"
            DIRS = ${builtins.toJSON cfg.gameDirs}


            def log(msg):
                msg = re.sub(r"key=[^&\s]+", "key=***", msg)
                LOG.parent.mkdir(parents=True, exist_ok=True)
                with LOG.open("a") as f:
                    f.write(time.strftime("%F %T ") + msg + "\n")
                print(msg, file=sys.stderr)


            def notify(title, body):
                if DRY:
                    return
                subprocess.run(["${pkgs.libnotify}/bin/notify-send", "-a", "nxm-handler", title, body], check=False)


            def main():
                if len(sys.argv) != 2:
                    sys.exit("usage: nxm-handler nxm://game/mods/ID/files/ID?key=..&expires=..")
                url = urllib.parse.urlparse(sys.argv[1])
                m = re.fullmatch(r"/mods/(\d+)/files/(\d+)", url.path)
                if url.scheme != "nxm" or not m or not re.fullmatch(r"[A-Za-z0-9_-]+", url.netloc):
                    log("rejected malformed link")
                    notify("Nexus: bad link", "Not an nxm download link")
                    sys.exit(1)
                game, (mod, fid) = url.netloc, m.groups()
                q = urllib.parse.parse_qs(url.query)
                dest = ROOT / DIRS.get(game, game)
                link_args = {k: q[k][0] for k in ("key", "expires") if k in q}
                log(f"parsed game={game} mod={mod} file={fid} expires={link_args.get('expires')} dest={dest}")
                if DRY:
                    print(f"DRY RUN: would GET {API}/v1/games/{game}/mods/{mod}/files/{fid}/download_link.json?key=***&expires=... -> {dest}")
                    return
                try:
                    apikey = KEYFILE.read_text().strip()
                    api = f"{API}/v1/games/{game}/mods/{mod}/files/{fid}/download_link.json?{urllib.parse.urlencode(link_args)}"
                    hdr = {"apikey": apikey, "User-Agent": "dafos-nxm-handler"}
                    with urllib.request.urlopen(urllib.request.Request(api, headers=hdr), timeout=30) as r:
                        uris = [e["URI"] for e in json.load(r)]
                    # The CDN names the file with a bare UUID, in the URL and in
                    # Content-Disposition alike: the API's file_name is the real one
                    # (same pattern as a browser download from the site).
                    name = None
                    try:
                        meta = urllib.request.Request(f"{API}/v1/games/{game}/mods/{mod}/files/{fid}.json", headers=hdr)
                        with urllib.request.urlopen(meta, timeout=30) as m:
                            name = json.load(m).get("file_name")
                    except Exception as e:  # noqa: BLE001
                        log(f"file_name lookup failed: {type(e).__name__}")
                    dest.mkdir(parents=True, exist_ok=True)
                    last = None
                    # The API lists several mirrors: a stalled CDN is retried on the next.
                    for uri in uris:
                        part = None
                        try:
                            # The CDN path can hold raw spaces, which urllib rejects.
                            u = urllib.parse.urlsplit(uri)
                            uri = u._replace(path=urllib.parse.quote(u.path, safe="/%")).geturl()
                            dl = urllib.request.Request(uri, headers={"User-Agent": "dafos-nxm-handler"})
                            with urllib.request.urlopen(dl, timeout=60) as r:
                                fname = Path(name or r.headers.get_filename() or "").name
                                if not fname or fname.startswith("."):
                                    raise ValueError("no usable file name")
                                target = dest / fname
                                size = int(r.headers.get("Content-Length", -1))
                                if target.exists() and target.stat().st_size == size:
                                    log(f"skip {fname}: already present")
                                    notify("Nexus: already there", fname)
                                    return
                                part = target.with_name(fname + ".part")
                                done = 0
                                with part.open("wb") as f:
                                    while chunk := r.read(1 << 20):
                                        f.write(chunk)
                                        done += len(chunk)
                                if size >= 0 and done != size:
                                    raise OSError(f"truncated: {done} of {size} bytes")
                                part.rename(target)
                            log(f"ok {fname} -> {dest}")
                            notify("Nexus: downloaded", f"{fname} -> {dest}")
                            return
                        except Exception as e:  # noqa: BLE001
                            last = e
                            log(f"mirror {urllib.parse.urlsplit(uri).netloc} failed mod={mod} file={fid}: {type(e).__name__}: {e}")
                            if part is not None:
                                part.unlink(missing_ok=True)
                    raise last or ValueError("no download mirror returned")
                except Exception as e:  # noqa: BLE001
                    log(f"failed mod={mod} file={fid}: {type(e).__name__}: {e}")
                    notify("Nexus: download failed", f"mod {mod} file {fid}: {type(e).__name__}")
                    sys.exit(1)


            main()
          '';

      # Opens the next missing file of a Nexus collection, one per call, so
      # every download stays a click of yours.
      next =
        pkgs.writers.writePython3Bin "nxm-next"
          {
            flakeIgnore = [
              "E501"
              "E231"
            ];
          }
          ''
            import json
            import os
            import subprocess
            import sys
            from pathlib import Path

            data = Path(os.environ.get("NXM_NEXT_DATA", "${cfg.next.data}")).expanduser()
            dest = Path(os.environ.get("NXM_DEST", Path.home() / "Downloads" / "mods")) / "${cfg.next.dir}"
            files = json.loads(data.read_text())["data"]["collection"]["latestPublishedRevision"]["modFiles"]
            have = set(os.listdir(dest)) if dest.is_dir() else set()


            def present(m):
                # uri is the CDN name for old files, a bare UUID path for new ones:
                # those land as "<file name> <mod id> <version> ..." instead.
                f = m["file"]
                if f["uri"] in have:
                    return True
                mid = str(f["modId"])
                return any(n.startswith(f["name"]) and mid in n for n in have)


            missing = [m for m in files if not present(m)]
            if not missing:
                print("nothing left: every file is already in " + str(dest))
                sys.exit(0)
            m = missing[0]
            f = m["file"]
            url = f"https://www.nexusmods.com/${cfg.next.game}/mods/{f['modId']}?tab=files&file_id={m['fileId']}&nmm=1"
            print(f"{len(missing)} left of {len(files)}; opening: {f['mod']['name']} ({f['name']})")
            if "--print" in sys.argv:
                print(url)
            else:
                subprocess.run(["xdg-open", url], check=False)
          '';
    in
    {
      options.dafos.programs.nxm-handler = {
        enable = lib.mkEnableOption "the nxm:// download handler for Nexus Mods";
        next = {
          data = lib.mkOption {
            type = lib.types.str;
            default = "~/Games/cyberpunk-mods/rev484/collection-graphql.json";
            description = "Collection GraphQL dump (modFiles) read by nxm-next.";
          };
          game = lib.mkOption {
            type = lib.types.str;
            default = "cyberpunk2077";
            description = "Nexus game domain used in the links nxm-next opens.";
          };
          dir = lib.mkOption {
            type = lib.types.str;
            default = "cyberpunk";
            description = "Folder under ~/Downloads/mods holding what is already downloaded.";
          };
        };
        gameDirs = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = {
            cyberpunk2077 = "cyberpunk";
          };
          description = "Nexus game domain to folder name under ~/Downloads/mods (default: the domain).";
        };
      };

      config = lib.mkIf cfg.enable {
        home.packages = [
          handler
          next
        ];

        xdg.desktopEntries.nxm-handler = {
          name = "Nexus Mods downloader";
          exec = "${lib.getExe handler} %u";
          mimeType = [ "x-scheme-handler/nxm" ];
          noDisplay = true;
          terminal = false;
        };

        xdg.mimeApps = {
          enable = true;
          defaultApplications."x-scheme-handler/nxm" = lib.mkForce [ "nxm-handler.desktop" ];
          associations.added."x-scheme-handler/nxm" = lib.mkForce [ "nxm-handler.desktop" ];
        };
      };
    };
}
