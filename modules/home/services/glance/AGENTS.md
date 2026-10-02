# Glance dashboard

- **Categories live in the `categories` table here**, not in
  `dashboard.category` (that one also feeds Homepage). An unlisted container
  lands in « Autres »; give it a real category instead of leaving it there.
- **A docker-containers widget needs `category`.** Glance lists every container
  on the socket and filters on it; without it each widget shows the whole host,
  databases included. The per-container overrides must carry the same category.
- **Link-less containers stay visible** (flaresolverr, gluetun, ...): their
  status tick is the point. Don't nest them under a parent to save space; a
  child's status only shows in the parent's hover popover.
- **nps's own docker-containers widgets are discarded** with `lib.mkForce` on
  `pages.home.columns.center.widgets`. Our widgets copy the shape of nps's
  `modules/glance/extension.nix`; recheck it after an nps bump.
- **Page order is attribute-name order** (nps applies `attrValues`). `home`
  stays first, the rest are `p<N>-<slug>`.
- **Disk usage = statfs on a bind-mounted directory.** Mount an empty or
  harmless directory from each filesystem, never `/` (it would expose daf's sops
  key). Freebox CIFS shares are left out: statfs on an unreachable share hangs.
  With `hide-mountpoints-by-default`, every listed mountpoint needs
  `hide = false` or it is hidden too.
- UI strings are in French. Glance has no i18n, so the built-in labels
  (calendar, weather, "x hours ago") stay English.
- **`engine = "dynacat"`** swaps the image for the Dynacat fork and mounts the
  same config as `/app/config/dynacat.yml`. If that file is missing, Dynacat
  serves a first-run setup page that lets anyone write the config. Validate with
  `dynacat --config <file> config:validate`; it checks that `assets-path`
  exists, so point it at a local directory when you run it outside the
  container.
- **Dynacat's UI editor is on by default, with no auth.** Keep
  `server.allow-editing = false`; Authelia does not stand in for it. The startup
  log warns when it is on.
- **Test custom-api templates locally** before deploying: build Dynacat
  (`go build`), run it on the generated config with a local `assets-path` and a
  spare port, and fetch `/api/pages/<slug>/content/`.
- `football.nix`: ESPN rejects `dates=` ranges with 400 but accepts a month
  (`YYYYMM`), so the widget fetches the months within three weeks of today.
- `national-teams.nix`: per-team schedule under ESPN's `all` league, two calls
  (`fixture=true`, `season=<year>`). Team ids come from any international
  league's `/teams` list (France 478, Portugal 482).
- **Release calendar keys** (`sonarr/api-key`, `radarr/api-key` in
  `secrets/dafoltop/streaming.yaml`) are copies of the apps' generated keys in
  `<stack>/config.xml`; regenerating one in the app means updating sops. A
  `${VAR}` the container lacks makes Dynacat refuse the whole config, so the
  dashboard goes down, not just the widget.
- `rer.nix`: PRIM stop-monitoring, token `prim/api-key` in
  `secrets/dafoltop/glance.yaml`. SIRI's `DirectionRef` is "Retour" for every
  RER A train, so direction is chosen by excluding the other side's
  destinations. Stop ids are IDFM "zones d'arrêt" (`zones-d-arrets` dataset).
- **A brand-new secret can land empty on its first deploy.** sops-nix ran twice
  during activation and glance built its env file in between, so `PRIM_API_KEY`
  was blank and PRIM answered 401. After adding a secret, check
  `/run/user/1000/glance/extra_env/from_file_content` (lengths, not values) and
  `systemctl --user restart podman-glance` if one is empty.
- `health.nix` (Accueil) lists only broken containers and host services and
  calls `hide` otherwise. Dynacat's `getResponse` rejects a 2xx non-JSON body as
  status 0 / "invalid response JSON", so that error counts as "up". Test both
  paths against a fake socket-proxy (a static `containers/json` served over
  HTTP).
- **Header link buttons** (`linkButton` in `default.nix`): widget headers only
  take a title link, so the button is drawn in the template body and pinned to
  the header row by `userCss`. Dynacat's root font size is 10px; size in rem
  accordingly. FotMob ids come from
  `fotmob.com/api/data/search/suggest?term=<name>`.
- `weather-week.nix`: Open-Meteo daily forecast (the built-in `weather` widget
  has no multi-day option), WMO codes mapped to French labels and MDI
  `weather-*` icons. Index parallel `daily.*` arrays with
  `printf "daily.x.%d" $i` from the root, not through the range variable.
