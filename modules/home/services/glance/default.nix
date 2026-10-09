{
  lib,
  config,
  inputs,
  osConfig,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.services.glance;
  domain = config.${namespace}.services.traefik.base-url;

  dynacat = {
    # renovate: versioning=semver
    image = "docker.io/panonim/dynacat:3.0.1";
  };

  # `update-interval` is how Dynacat refreshes a widget in place; upstream
  # Glance does not know the key.
  liveWidget = w: if cfg.engine == "dynacat" then w else removeAttrs w [ "update-interval" ];

  # A site-logo button that opens the source of a widget's data. The header
  # only takes a title link, so custom-api widgets draw the button in their
  # body and `userCss` pins it to the header row (see `.widget-link-button`).
  # `inline` keeps it in the flow, beside a sub-heading.
  linkButton =
    {
      title,
      url,
      icon,
      inline ? false,
    }:
    ''<a class="${
      if inline then "inline-link-button" else "widget-link-button"
    }" href="${url}" target="_blank" rel="noreferrer" title="${title}"><img src="${icon}" alt="${title}"></a>'';

  fotmob =
    inline: path:
    linkButton {
      inherit inline;
      title = "Ouvrir dans FotMob";
      url = "https://www.fotmob.com/${path}";
      icon = "https://www.fotmob.com/img/android-icon-192x192.png";
    };
  fotmobButton = fotmob false;
  fotmobLink = fotmob true;

  # FotMob has no basketball.
  nbaStandings = linkButton {
    title = "Ouvrir sur NBA.com";
    url = "https://www.nba.com/standings";
    icon = "https://cdn.nba.com/logos/leagues/logo-nba.svg";
  };

  # Dynacat's calendar can show Sonarr/Radarr releases. It reaches them over
  # the shared traefik-proxy network, not their public routes, which sit
  # behind Authelia; `public-url` is only for the links it renders.
  arrs = lib.filter (a: config.nps.stacks.streaming.${a}.enable or false) [
    "sonarr"
    "radarr"
  ];
  arrPorts = {
    sonarr = 8989;
    radarr = 7878;
  };
  releaseCalendar = cfg.engine == "dynacat" && config.nps.stacks.streaming.enable && arrs != [ ];
  envName = app: "${lib.toUpper app}_API_KEY";

  # Where host filesystems appear inside the container, for server-stats.
  hostfs = "/hostfs";

  # The filesystems server-stats reports, also handed to this host's Glance
  # agent so the « État des hôtes » widget can warn about a full one. Keys
  # name the path under `hostfs`. Each source is a directory that holds
  # nothing worth reading: a bind of `/` would hand the container everything
  # daf can read, sops age key included.
  hostDisks = {
    root = {
      source = "/var/empty";
      name = "Système";
    };
    # An empty directory on /home, the one filesystem with no such directory
    # already.
    home = {
      source = "${config.xdg.stateHome}/glance-statfs";
      name = "Home";
    };
    # Media library only, and read-only.
    data = {
      source = "/mnt/data";
      name = "Médias";
    };
    # Holds only the root-owned 0700 restic repo, unreadable here.
    backup = {
      source = "/mnt/backup";
      name = "Sauvegardes";
    };
  };

  # The filesystems server-stats reports, also handed to this host's Glance
  # agent so the « État des hôtes » widget can warn about a full one. Keys
  # name the path under `hostfs`. Each source is a directory that holds
  # nothing worth reading: a bind of `/` would hand the container everything
  # daf can read, sops age key included.

  # Services that run as NixOS services on dafoltop, not as nps containers, so
  # the docker-containers widgets never see them. A monitor widget gives them
  # the same status checkmark. The check goes to the port Traefik proxies to
  # (see the `*-nix` routers in ../traefik) rather than the public hostname,
  # so a green tick means the service is up, not merely that Traefik is.
  # A service on another host gives its `url` (and `checkUrl`) instead.
  mkSite =
    {
      title,
      icon,
      port ? null,
      subDomain ? null,
      url ? null,
      checkUrl ? url,
    }:
    let
      internal = "http://host.containers.internal:${toString port}";
    in
    if url != null then
      {
        inherit title icon url;
        check-url = checkUrl;
      }
    else
      {
        inherit title icon;
        # Status-only services have no public route. Their link only resolves
        # from inside the glance container.
        url = if subDomain != null then "https://${subDomain}.${domain}" else internal;
        check-url = internal;
      };

  # Glance's own categories, not `dashboard.category`: that one also feeds
  # Homepage, and nps's generic buckets ("General" holds ten unrelated apps)
  # say nothing about what a service is for. Keys are top-level containers;
  # children follow their `parent`. `sites` are host services, shown as a
  # headerless monitor right under the category so they read as part of it.
  categories = [
    {
      title = "Médias";
      icon = "mdi:movie-open";
      page = "medias";
      containers = [
        "jellyfin"
        "seerr"
      ];
    }
    {
      title = "Photos";
      icon = "mdi:image-multiple";
      page = "medias";
      containers = [ "immich-kiosk" ];
      oneList = true;
      sites = [
        {
          title = "Immich";
          subDomain = "immich";
          port = 2283;
          icon = "di:immich";
        }
      ];
    }
    {
      title = "Lecture";
      icon = "mdi:book-open-variant";
      page = "medias";
      containers = [
        "bookorbit"
        "calibre"
        "grimmory"
        "shelfmark"
      ];
    }
    {
      title = "Yahrr";
      icon = "mdi:pirate";
      page = "medias";
      containers = [
        "sonarr"
        "radarr"
        "bazarr"
        "prowlarr"
        "profilarr"
        "qbittorrent"
        "qui"
        "flaresolverr"
      ];
    }
    {
      title = "Domotique";
      icon = "mdi:home-automation";
      page = "services";
      containers = [ ];
      sites = [
        {
          title = "Home Assistant";
          subDomain = "home";
          port = 8123;
          icon = "di:home-assistant";
        }
        {
          title = "Zigbee2MQTT";
          subDomain = "z2m";
          port = 8090;
          icon = "di:zigbee2mqtt";
        }
        {
          title = "Configurateur de zones";
          subDomain = "zones";
          port = 42069;
          icon = "mdi:radar";
        }
      ];
    }
    {
      title = "Maison & quotidien";
      icon = "mdi:home";
      page = "services";
      containers = [
        "kitchenowl-backend"
        "norish"
        "bar-assistant-salt-rim"
        "sparky-fitness-frontend"
      ];
    }
    {
      title = "Organisation";
      icon = "mdi:checkbox-marked-circle-outline";
      page = "services";
      containers = [
        "donetick"
        "kaneo-web"
      ];
    }
    {
      title = "Papiers & finances";
      icon = "mdi:wallet";
      page = "services";
      containers = [
        "securo"
        "spliit"
        "papra"
      ];
      oneList = true;
    }
    {
      title = "Outils";
      icon = "mdi:tools";
      page = "services";
      containers = [ "it-tools" ];
    }
    {
      title = "Supervision";
      icon = "mdi:monitor-eye";
      page = "monitoring";
      containers = [ "dozzle" ];
      sites = [
        {
          # Native on dafpi, behind its Traefik (traefik hostRoutes).
          title = "Gatus";
          url = "https://gatus.${domain}";
          checkUrl = "https://gatus.${domain}/health";
          icon = "di:gatus";
        }
      ];
    }
    {
      title = "Infra & sécurité";
      icon = "mdi:shield-lock";
      page = "monitoring";
      containers = [
        "traefik"
        "authelia"
        "lldap"
        "crowdsec"
        "gluetun"
        "socket-proxy"
      ];
      sites = [
        {
          # Home Assistant's notification text comes from here.
          title = "Ollama";
          port = 11434;
          icon = "di:ollama";
        }
        {
          title = "Blocky";
          port = 4000;
          icon = "di:blocky";
        }
      ];
    }
  ];

  # Catches any container the table above does not list, so a new service
  # still shows up somewhere instead of silently vanishing.
  fallbackCategory = {
    title = "Autres";
    icon = "mdi:package-variant";
    page = "services";
    containers = [ ];
  };

  descriptions = {
    authelia = "Authentification unique (SSO)";
    bar-assistant-salt-rim = "Recettes de cocktails et inventaire du bar";
    bazarr = "Sous-titres";
    bookorbit = "Espace de lecture";
    calibre = "Bibliothèque d'ebooks";
    crowdsec = "Protection collaborative contre les attaques";
    donetick = "Tâches du quotidien";
    flaresolverr = "Contournement de Cloudflare";
    gluetun = "Client VPN";
    grimmory = "Collection de livres";
    immich-kiosk = "Cadre photo Immich";
    jellyfin = "Serveur multimédia";
    kaneo-web = "Gestion de projets";
    kitchenowl-backend = "Courses et recettes";
    lldap = "Annuaire des utilisateurs";
    norish = "Recettes";
    papra = "Gestion de documents";
    profilarr = "Profils de qualité";
    prowlarr = "Indexeurs";
    qbittorrent = "Client BitTorrent";
    qui = "Interface qBittorrent";
    radarr = "Films";
    securo = "Finances personnelles";
    seerr = "Demandes de films et séries";
    shelfmark = "Téléchargement de livres";
    socket-proxy = "Proxy sécurisé du socket Podman";
    sonarr = "Séries";
    sparky-fitness-frontend = "Suivi sportif et nutrition";
    spliit = "Partage de dépenses";
    traefik = "Reverse proxy";
  };

  glanceCfg = config.nps.stacks.glance;

  # Same selection nps's extension.nix makes: a null category hides it.
  shown = lib.filterAttrs (_: c: c.glance.category != null) config.services.podman.containers;

  # `parent` names the parent's glance id, which is not always its container
  # name (bar-assistant's id sits on bar-assistant-salt-rim).
  containerOfId = lib.mapAttrs' (name: c: lib.nameValuePair c.glance.id name) (
    lib.filterAttrs (_: c: c.glance.id != null) shown
  );

  categoryOfTop =
    top: (lib.findFirst (cat: lib.elem top cat.containers) fallbackCategory categories).title;

  categoryOf =
    name:
    let
      parent = shown.${name}.glance.parent or null;
    in
    categoryOfTop (if parent != null then containerOfId.${parent} or parent else name);

  # Apps on the hosts this one's Traefik relays to (traefik `peers`, dafpi).
  # The docker-containers widgets only see this host's socket, and a peer's
  # is not exposed over the network (an inspect returns the containers'
  # environment, secrets included), so each routed app becomes a monitor
  # entry instead, filed by container name like the local ones. A name that
  # also runs here (traefik) gets the host as a suffix.
  peerHosts = lib.attrNames config.${namespace}.services.traefik.peers;
  peerContainers =
    peer:
    inputs.self.nixosConfigurations.${peer}.config.home-manager.users.daf.services.podman.containers;
  peerApps = lib.concatMap (
    peer:
    lib.mapAttrsToList
      (name: c: {
        inherit name;
        category = categoryOfTop name;
        site = {
          title =
            if config.services.podman.containers ? ${name} then "${c.glance.name} · ${peer}" else c.glance.name;
          inherit (c.glance) icon url;
          check-url = c.glance.url;
        };
      })
      (
        lib.filterAttrs (
          # Top-level entries with a link, routed or not: kitchenowl's entry is
          # its backend, the routed frontend being its child.
          _: c: (c.glance.url or "") != "" && c.glance.category != null && c.glance.parent == null
        ) (peerContainers peer)
      )
  ) peerHosts;
  # Unauthenticated status pages, for apps whose root wants a login.
  checkPaths.immich-kiosk = "/health";

  peerAppsIn = cat: lib.filter (a: a.category == cat.title) peerApps;

  # The peers running a Glance agent (flake-modules/services/glance-agent.nix).
  agentPeers = lib.filter (peer: (peerContainers peer) ? glance-agent) peerHosts;

  # One widget per category, in the shape nps's extension.nix generates.
  # Glance asks the socket for every container and keeps those whose
  # `category` matches the widget's, so both must carry our title; without
  # it each widget lists every container on the host, children included.
  #
  # Host services and peer apps go in a monitor widget below it, a separate
  # grid. A `oneList` category puts its linked local containers in that
  # monitor too, so the whole category reads as one list in table order
  # (Immich beside its kiosk, Spliit between the dafpi apps). Their children
  # leave the page with them; « Services en panne » still watches those.
  categoryWidgets =
    cat:
    let
      inCategory = lib.filterAttrs (name: _: categoryOf name == cat.title) shown;
      linked = lib.filterAttrs (
        _: c: (cat.oneList or false) && c.glance.parent == null && (c.glance.url or "") != ""
      ) inCategory;
      linkedIds = lib.catAttrs "id" (map (c: c.glance) (lib.attrValues linked));
      members = lib.filterAttrs (
        name: c: !(linked ? ${name}) && !(lib.elem (c.glance.parent or null) linkedIds)
      ) inCategory;

      rank = name: lib.lists.findFirstIndex (n: n == name) 1000 cat.containers;
      apps = lib.sort (a: b: rank a.name < rank b.name) (
        peerAppsIn cat
        ++ lib.mapAttrsToList (name: c: {
          inherit name;
          site = {
            inherit (c.glance) icon url;
            title = c.glance.name;
            # Over the shared traefik-proxy network: the public route can
            # sit behind a login (the kiosk's answers 401).
            check-url = "http://${name}:${toString c.port}${checkPaths.${name} or ""}";
          };
        }) linked
      );
      sites = map mkSite (cat.sites or [ ]) ++ map (a: a.site) apps;
    in
    lib.optional (members != { }) (
      {
        type = "docker-containers";
        inherit (cat) title;
        title-icon = cat.icon;
        category = cat.title;
        running-only = false;
        cache = "30s";
        containers = lib.mapAttrs (
          name: c:
          c.glance
          // {
            category = cat.title;
          }
          // lib.optionalAttrs (descriptions ? ${name}) { description = descriptions.${name}; }
        ) members;
      }
      // lib.optionalAttrs glanceCfg.useSocketProxy {
        sock-path = config.nps.stacks.socket-proxy.address;
      }
    )
    ++ lib.optional (sites != [ ]) (
      {
        type = "monitor";
        cache = "1m";
        inherit sites;
      }
      # The category's header, when no local container widget carries it (all
      # of "Outils" moved to dafpi).
      // (
        if members != { } then
          { hide-header = true; }
        else
          {
            inherit (cat) title;
            title-icon = cat.icon;
          }
      )
    );

  widgetsFor =
    page:
    lib.concatMap categoryWidgets (
      lib.filter (cat: cat.page == page) (categories ++ [ fallbackCategory ])
    );
in
{

  options.${namespace}.services.glance = {
    enable = mkEnableOption "Whether or not to configure glance.";
    subDomain = mkOpt types.str "fp" "The base url";
    engine =
      mkOpt
        (types.enum [
          "glance"
          "dynacat"
        ])
        "glance"
        "Which binary renders the dashboard: upstream Glance, or the Dynacat fork (live widget updates).";
  };

  config = mkIf cfg.enable {
    # Created at activation, before the container restarts; a missing bind
    # source would keep glance from starting.
    xdg.stateFile."glance-statfs/.keep".text = "";
    ${namespace}.services.glance-agent.mountpoints =
      lib.mkIf config.${namespace}.services.glance-agent.enable
        hostDisks;

    # Copied from each app's config.xml, where Sonarr/Radarr generate them.
    # Regenerating a key in the app means updating it here too.
    sops.secrets = lib.mkMerge [
      (lib.mkIf releaseCalendar (
        lib.genAttrs (map (a: "${a}/api-key") arrs) (_: {
          sopsFile = lib.snowfall.fs.get-file "secrets/dafoltop/streaming.yaml";
        })
      ))
      # PRIM (Île-de-France Mobilités) token for the RER widget, generated
      # under "Mon jeton d'API" on prim.iledefrance-mobilites.fr.
      { "prim/api-key".sopsFile = lib.snowfall.fs.get-file "secrets/dafoltop/glance.yaml"; }
      # Shared with the agents' hosts (flake-modules/services/glance-agent.nix).
      (lib.mkIf (agentPeers != [ ]) {
        # Same path value as the agent aspect declares it with (one definition).
        "glance-agent/token".sopsFile = inputs.self + "/secrets/dafoltop/glance-agent.yaml";
      })
    ];

    services.podman.containers.glance.extraEnv = lib.mkMerge [
      (lib.mkIf releaseCalendar (
        lib.listToAttrs (
          map (a: lib.nameValuePair (envName a) { fromFile = config.sops.secrets."${a}/api-key".path; }) arrs
        )
      ))
      { PRIM_API_KEY.fromFile = config.sops.secrets."prim/api-key".path; }
      (lib.mkIf (agentPeers != [ ]) {
        GLANCE_AGENT_TOKEN.fromFile = config.sops.secrets."glance-agent/token".path;
      })
    ];

    nps.stacks = {
      glance = {
        enable = true;

        containers = {
          glance = {
            expose = true;
            traefik.subDomain = cfg.subDomain;

            # Glance ships no authentication of its own, and this dashboard
            # publishes dafoltop's server stats plus a bookmark map of the
            # internal services. Everything else on the public chain
            # authenticates somehow -- OIDC against Authelia, or the app's own
            # login -- so gate this one on Authelia too. `default_policy` is
            # `one_factor`, so no per-app rule or client secret is needed.
            forwardAuth.enable = true;

            # Templates render match and train times with the container's
            # local zone. Dynacat embeds time/tzdata, so the alpine
            # image needs no zoneinfo for this.
            environment.TZ = "Europe/Paris";

            # server-stats statfs()es each mountpoint path, and any directory
            # on a filesystem reports that filesystem's usage. Without these the
            # container only sees its own overlay (see `hostDisks`).
          }
          // lib.optionalAttrs (cfg.engine == "dynacat") {
            # Dynacat reads the same config format, and the `glance.*`
            # container overrides too. It only looks for a different file
            # name; a missing config would serve its first-run setup page,
            # which lets anyone write the config.
            image = lib.mkForce dynacat.image;
            volumeMap.settings = lib.mkForce "${config.nps.stacks.glance.settings}:/app/config/dynacat.yml";
          }
          // {
            volumes = lib.mapAttrsToList (key: d: "${d.source}:${hostfs}/${key}:ro") hostDisks;
          };
        };

        settings.branding = {
          logo-text = "dafos";
          # The footer is the only place Dynacat renders raw HTML straight
          # into the page, so it carries the page scripts: the RER countdown
          # and the Monitoring tab alert (widget templates arrive via
          # innerHTML, where a <script> never runs). `.footer` itself is
          # hidden in userCss.
          custom-footer = lib.concatMapStrings (f: "<script>${builtins.readFile f}</script>") [
            ./rer-ticker.js
            ./monitoring-alert.js
          ];
        }
        // lib.optionalAttrs (cfg.engine == "dynacat") {
          # Home-screen name when installed as an app; defaults to "Dynacat".
          app-name = "dafos";
        };

        # HSL triplets ("hue saturation lightness"): a near-black background
        # and orange accents. The "negative" colour marks every failure, ours
        # (RER misses, alerts, the Monitoring tab) and Dynacat's (monitor
        # errors, stopped containers), so it stays red: the theme's blue
        # (209 88 54) did not read as an error.
        settings.theme = {
          background-color = "50 1 6";
          primary-color = "24 97 58";
          negative-color = "4 80 58";
        };

        # Bookmark icons sit at 0.7 (container) × 0.8 (icon) opacity, which
        # leaves them barely visible on the dark theme.
        userCss = ''
          .bookmarks-icon-container { opacity: 1; }
          .bookmarks-icon { opacity: 0.9; }

          /* Monochrome header icons (title-icon = "mdi:…") in the title grey
             rather than the flat-icon invert's pure white; the selector has
             to outrank Dynacat's own dark-scheme `.flat-icon` rule. */
          :root:not([data-scheme="light"]) .widget-title-icon.flat-icon {
            filter: invert(0.58);
          }

          /* RER departures (rer.nix): a stripe per row saying whether the
             walk to the station still makes it. Fixed colours rather than
             theme tokens: Dynacat's positive colour defaults to the primary
             purple, which says nothing here. */
          .rer-row {
            border-left: 0.4rem solid transparent;
            padding-left: 0.8rem;
            border-radius: 0.2rem;
          }
          .rer-ok { border-left-color: hsl(135, 45%, 50%); }
          .rer-ok .rer-status { color: hsl(135, 45%, 50%); }
          .rer-hurry { border-left-color: hsl(38, 85%, 60%); }
          .rer-hurry .rer-status { color: hsl(38, 85%, 60%); }
          .rer-missed { border-left-color: var(--color-negative); opacity: 0.45; }
          .rer-missed .rer-status { color: var(--color-negative); }

          /* Standings (standings.nix): a stripe per zone, same palette. */
          .standings-row {
            border-left: 0.3rem solid transparent;
            padding-left: 0.6rem;
          }
          .standings-top { border-left-color: hsl(135, 45%, 50%); }
          .standings-mid { border-left-color: hsl(38, 85%, 60%); }
          .standings-down { border-left-color: var(--color-negative); }

          /* Host temperatures (temperatures.nix), same palette as the RER rows. */
          .temp-ok { color: hsl(135, 45%, 50%); }
          .temp-warm { color: hsl(38, 85%, 60%); }
          .temp-hot { color: var(--color-negative); }
          .rer-cancelled { opacity: 0.45; }
          /* Spare rows wait hidden until rer-ticker.js promotes them; the
             list's flex rows would otherwise override [hidden]. */
          .rer-list > li[hidden], .rer-extra, .rer-empty[hidden] { display: none !important; }
          .rer-refresh { border: 0; cursor: pointer; }
          .rer-refresh.is-loading img { animation: rer-spin 0.8s linear infinite; }
          @keyframes rer-spin { to { rotate: 360deg; } }

          /* Monitoring tab while an alert shows (monitoring-alert.js). */
          .nav-item.nav-item-alert {
            color: var(--color-negative);
            animation: nav-alert 2s ease-in-out infinite;
          }
          .nav-item.nav-item-alert::before {
            content: "";
            display: inline-block;
            width: 0.7rem;
            height: 0.7rem;
            margin-right: 0.6rem;
            border-radius: 50%;
            background: var(--color-negative);
          }
          @keyframes nav-alert { 50% { opacity: 0.6; } }

          /* Footer holds only page scripts (branding.custom-footer). */
          .footer { display: none; }

          /* Site-logo buttons (linkButton). The absolute one is centred on
             the header row of the nearest positioned widget; inside a group
             that is the group itself, so each tab's button lands on the tab
             bar and only the current tab's shows. The root font size is
             10px, hence the larger rem values. */
          .widget:has(.widget-link-button) { position: relative; }
          .widget-type-group .widget { position: static; }
          .widget:has(> .widget-content .widget-link-button) > .widget-header {
            padding-right: 5rem;
          }
          .widget-link-button {
            position: absolute;
            top: 1.1rem;
            right: calc(var(--widget-content-horizontal-padding) + 1px);
            transform: translateY(-50%);
          }
          .widget-type-group .widget-link-button { top: 2.7rem; }
          /* Several buttons in one header (RER: refresh + Citymapper). */
          .widget:has(.widget-link-button-group) { position: relative; }
          .widget:has(> .widget-content .widget-link-button-group) > .widget-header {
            padding-right: 9rem;
          }
          .widget-link-button-group {
            position: absolute;
            top: 1.1rem;
            right: calc(var(--widget-content-horizontal-padding) + 1px);
            transform: translateY(-50%);
            display: flex;
            gap: 0.6rem;
          }
          .widget-link-button-group .widget-link-button {
            position: static;
            transform: none;
          }
          .widget-link-button, .inline-link-button {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            width: 3.2rem;
            height: 3.2rem;
            border-radius: var(--border-radius);
            background: var(--color-widget-background-highlight);
            opacity: 0.85;
            transition: opacity 0.2s, scale 0.2s;
          }
          .inline-link-button { width: 2.8rem; height: 2.8rem; }
          .widget-link-button:hover, .inline-link-button:hover {
            opacity: 1;
            scale: 1.08;
          }
          .widget-link-button img, .inline-link-button img {
            width: 70%;
            height: 70%;
            border-radius: 0.4rem;
          }
        '';

        # Dynacat's web UI editor defaults to on, with no auth of its own;
        # Authelia only proves who you are, not that you may rewrite the
        # dashboard. The config is a read-only store file anyway, but don't
        # offer the editor at all.
        settings.server = lib.optionalAttrs (cfg.engine == "dynacat") {
          allow-editing = false;
        };

        # nps turns `pages` into a list with attrValues, so pages appear in
        # attribute-name order. `home` must stay the first page (nps puts its
        # docker-containers widgets there), hence the numbered keys after it;
        # `slug` keeps the URLs clean.
        settings.pages.home = {
          name = "Accueil";
          columns.left = {
            rank = 500;
            size = "small";
            widgets = [
              (
                {
                  type = "calendar";
                  title = "Calendrier";
                  first-day-of-week = "monday";
                }
                // lib.optionalAttrs releaseCalendar {
                  show-release-state = true;
                  hosts = map (a: {
                    url = "${a}:http://${a}:${toString arrPorts.${a}}";
                    token = "\${${envName a}}";
                    public-url = config.services.podman.containers.${a}.glance.url;
                  }) arrs;
                }
              )
            ];
          };
          columns.center = {
            rank = 1000;
            size = "full";
            # Replaces the per-category widgets nps generates here: ours are
            # spread over the pages below.
            widgets = lib.mkForce [
              (liveWidget (
                import ./health.nix {
                  inherit lib;
                  socketUrl = lib.replaceStrings [ "tcp://" ] [ "http://" ] config.nps.stacks.socket-proxy.address;
                  # Children read "Parent · Child" (Securo · PostgreSQL),
                  # since a bare "PostgreSQL" could be any of several.
                  labels = lib.mapAttrs (
                    _: c:
                    let
                      parent = c.glance.parent or null;
                      parentName =
                        if containerOfId ? ${parent} then
                          config.services.podman.containers.${containerOfId.${parent}}.glance.name
                        else
                          parent;
                    in
                    if parent != null then "${parentName} · ${c.glance.name}" else c.glance.name
                  ) config.services.podman.containers;
                  sites = map (s: {
                    inherit (s) title;
                    url = s.check-url;
                  }) (map mkSite (lib.concatMap (cat: cat.sites or [ ]) categories) ++ map (a: a.site) peerApps);
                }
              ))
              {
                type = "search";
                search-engine = "google";
                placeholder = "Rechercher…";
                # The header is a hard-coded "Search"; the field says enough.
                hide-header = true;
                new-tab = false;
              }
              {
                type = "bookmarks";
                title = "Liens";
                groups = [
                  {
                    title = "Dev / Nix";
                    links = [
                      {
                        title = "dafos";
                        url = "https://github.com/CaptainSpof/dafos";
                        icon = "si:github";
                      }
                      {
                        title = "Paquets NixOS";
                        url = "https://search.nixos.org/packages";
                        icon = "si:nixos";
                      }
                      {
                        title = "Options NixOS";
                        url = "https://search.nixos.org/options";
                        icon = "si:nixos";
                      }
                      {
                        title = "Options Home Manager";
                        url = "https://home-manager-options.extranix.com/";
                        icon = "si:nixos";
                      }
                      {
                        title = "Noogle";
                        url = "https://noogle.dev";
                        icon = "mdi:function-variant";
                      }
                      {
                        title = "nix-podman-stacks";
                        url = "https://tarow.github.io/nix-podman-stacks/docs";
                        icon = "si:podman";
                      }
                    ];
                  }
                  {
                    title = "Web";
                    links = [
                      {
                        title = "YouTube";
                        url = "https://www.youtube.com";
                        icon = "si:youtube";
                      }
                      {
                        title = "Reddit";
                        url = "https://www.reddit.com";
                        icon = "si:reddit";
                      }
                      {
                        title = "GitHub Stars";
                        url = "https://github.com/CaptainSpof?tab=stars";
                        icon = "si:github";
                      }
                    ];
                  }
                  {
                    title = "Quotidien";
                    links = [
                      {
                        title = "Info trafic IDFM";
                        url = "https://www.iledefrance-mobilites.fr/info-trafic";
                        icon = "mdi:train";
                      }
                    ];
                  }
                ];
              }
            ];
          };
          columns.right = {
            rank = 1500;
            size = "small";
            widgets = [
              (liveWidget (
                import ./rer.nix {
                  title = "RER A → Paris";
                  # IDFM "zone d'arrêt" id, from the zones-d-arrets dataset on
                  # data.iledefrance-mobilites.fr.
                  stopArea = 43171;
                  # The western termini past Nanterre-Ville.
                  button = linkButton {
                    title = "Itinéraire depuis Nanterre-Ville dans Citymapper";
                    url = "https://citymapper.com/directions?startcoord=48.89502,2.19511&startname=Nanterre-Ville";
                    icon = "https://citymapper.com/favicon.ico?v=2";
                  };
                  excludeDestinations = [
                    "Saint-Germain-en-Laye"
                    "Le Vésinet-Le Pecq"
                    "Le Vésinet-Centre"
                    "Chatou-Croissy"
                    "Rueil-Malmaison"
                  ];
                }
              ))
              {
                type = "group";
                widgets = [
                  {
                    type = "weather";
                    title = "Aujourd'hui";
                    location = "Nanterre, France";
                  }
                  (liveWidget (
                    import ./weather-week.nix {
                      title = "Semaine";
                      # Nanterre, where the `weather` widget's geocoding lands.
                      latitude = 48.8924;
                      longitude = 2.2069;
                    }
                  ))
                ];
              }
            ];
          };
        };

        settings.pages.p1-services = {
          name = "Services";
          slug = "services";
          columns.main = {
            size = "full";
            widgets = widgetsFor "services";
          };
        };

        settings.pages.p2-medias = {
          name = "Médias";
          slug = "medias";
          columns.main = {
            rank = 1000;
            size = "full";
            widgets = widgetsFor "medias";
          };
        };

        settings.pages.p3-infos = {
          name = "Infos";
          slug = "infos";
          columns.main = {
            rank = 1000;
            size = "full";
            widgets = [
              {
                type = "group";
                widgets =
                  map (w: liveWidget (import ./scoreboard.nix w)) [
                    {
                      title = "Ligue des champions";
                      league = "soccer/uefa.champions";
                      button = fotmobButton "leagues/42/overview/champions-league";
                    }
                    {
                      title = "Ligue 1";
                      league = "soccer/fra.1";
                      button = fotmobButton "leagues/53/overview/ligue-1";
                    }
                  ]
                  ++ [
                    (liveWidget (
                      import ./national-teams.nix {
                        title = "Équipes nationales";
                        # ESPN team ids.
                        teams = [
                          {
                            name = "France";
                            flag = "🇫🇷";
                            id = "478";
                            link = fotmobLink "teams/6723/overview/france";
                          }
                          {
                            name = "Portugal";
                            flag = "🇵🇹";
                            id = "482";
                            link = fotmobLink "teams/8361/overview/portugal";
                          }
                        ];
                      }
                    ))
                    # FotMob has no basketball, hence NBA.com.
                    (liveWidget (
                      import ./scoreboard.nix {
                        title = "NBA";
                        league = "basketball/nba";
                        button = linkButton {
                          title = "Ouvrir sur NBA.com";
                          url = "https://www.nba.com/games";
                          icon = "https://cdn.nba.com/logos/leagues/logo-nba.svg";
                        };
                      }
                    ))
                  ];
              }
              {
                type = "group";
                widgets = map (w: liveWidget (import ./standings.nix w)) [
                  {
                    title = "Classement Ligue 1";
                    league = "soccer/fra.1";
                    button = fotmobButton "leagues/53/table/ligue-1";
                  }
                  {
                    title = "Classement LDC";
                    league = "soccer/uefa.champions";
                    # 36 clubs in the league phase.
                    collapseAfter = 24;
                    button = fotmobButton "leagues/42/table/champions-league";
                  }
                  {
                    title = "NBA Est";
                    league = "basketball/nba";
                    table = 0;
                    button = nbaStandings;
                  }
                  {
                    title = "NBA Ouest";
                    league = "basketball/nba";
                    table = 1;
                    button = nbaStandings;
                  }
                ];
              }
            ];
          };
          columns.right = {
            rank = 1500;
            size = "small";
            widgets = [
              {
                type = "reddit";
                title = "r/selfhosted";
                subreddit = "selfhosted";
                collapse-after = 5;
                # Reddit resets glance's connections when it refreshes its loid
                # cookie, and the refresh is synchronous, so whichever page load
                # hits an expired cache stalls for ~1s. Default TTL made that
                # roughly every 40 minutes.
                cache = "6h";
              }
            ];
          };
        };

        settings.pages.p4-monitoring = {
          name = "Monitoring";
          slug = "monitoring";
          columns.left = {
            rank = 500;
            size = "small";
            widgets = [
              {
                type = "server-stats";
                title = "Hôtes";
                servers = [
                  {
                    type = "local";
                    name = "dafoltop";
                    # Otherwise glance lists every bind mount in the container (the
                    # config file, user.css, ...). It then hides listed mountpoints too,
                    # unless they say `hide = false`.
                    hide-mountpoints-by-default = true;
                    mountpoints = lib.mapAttrs' (
                      key: d:
                      lib.nameValuePair "${hostfs}/${key}" {
                        inherit (d) name;
                        hide = false;
                      }
                    ) hostDisks;
                  }
                ]
                # Through the peer's Traefik (private gate). The agent picks
                # which mountpoints it reports.
                ++ map (peer: {
                  type = "remote";
                  name = peer;
                  url = (peerContainers peer).glance-agent.traefik.serviceUrl;
                  token = "\${GLANCE_AGENT_TOKEN}";
                }) agentPeers;
              }
              (liveWidget (
                import ./temperatures.nix {
                  inherit lib;
                  hosts =
                    lib.optional (config.services.podman.containers ? glance-agent) {
                      name = osConfig.networking.hostName;
                      url = config.services.podman.containers.glance-agent.traefik.serviceUrl;
                    }
                    ++ map (peer: {
                      name = peer;
                      url = (peerContainers peer).glance-agent.traefik.serviceUrl;
                    }) agentPeers;
                }
              ))
            ];
          };
          columns.main = {
            rank = 1000;
            size = "full";
            widgets = [
              (liveWidget (import ./gatus.nix { url = "https://gatus.${domain}"; }))
            ]
            ++ widgetsFor "monitoring";
          };
        };
      };
    };
  };
}
