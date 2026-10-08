# Rootless Traefik (nps stack) with a Cloudflare DNS-01 wildcard certificate,
# on every server: dafoltop (the public entry point) and dafpi (LAN/tailnet).
# The host has to let an unprivileged user bind :80/:443
# (net.ipv4.ip_unprivileged_port_start = 80) and open both ports.
{ inputs, ... }:
{
  flake.modules.homeManager.traefik =
    {
      lib,
      config,
      ...
    }:

    let
      inherit (lib)
        mkEnableOption
        mkIf
        mkOption
        types
        ;
      opt =
        type: default: description:
        mkOption { inherit type default description; };

      cfg = config.dafos.services.traefik;

      # nps routes traffic from other containers (reaching Traefik through its
      # network aliases) to a separate websecure-internal entrypoint, and its own
      # label routers attach to every entrypoint. A hand-written router pinned to
      # websecure alone answers those containers with a 404.
      entryPoints = [
        "websecure"
        "websecure-internal"
      ];

      # An empty `routers:` or `services:` makes Traefik reject the whole
      # dynamic file ("routers cannot be a standalone element"), private@file
      # included: on dafpi, with no native routers or redirects, every route
      # then failed with a 404.
      nonEmpty = attrs: mkIf (attrs != { }) attrs;

      # Every hostname a peer's own Traefik routes (its `routedHosts`),
      # relayed there from this one with the same gate (public@file for
      # exposed containers, else private@file): the Freebox forwards :443 to
      # dafoltop only, and tailnet clients outside the LAN come through here
      # too. On the LAN, blocky sends clients straight to the peer (blocky's
      # `peers`).
      peerHome = peer: inputs.self.nixosConfigurations.${peer}.config.home-manager.users.daf;
      peerPodmanContainers = peer: (peerHome peer).services.podman.containers;
      peerRouters = lib.concatMapAttrs (
        peer: _:
        lib.mapAttrs' (
          host: r:
          lib.nameValuePair "peer-${peer}-${lib.replaceStrings [ "." ] [ "-" ] host}" {
            rule = "Host(`${host}`)";
            service = "peer-${peer}";
            inherit entryPoints;
            middlewares = [ (if r.expose then "public@file" else "private@file") ];
            tls.certResolver = "letsencrypt"; # NPS default resolver name
          }
        ) (peerHome peer).dafos.services.traefik.routedHosts
      ) cfg.peers;
      # The peer's Traefik routes on the Host header. It is sniStrict (nps
      # default), so a connection to its bare address (no SNI) fails the
      # handshake and every relayed route answered 502: send its own
      # dashboard hostname as SNI, which the wildcard certificate covers and
      # verifies.
      peerServices = lib.mapAttrs' (
        peer: address:
        lib.nameValuePair "peer-${peer}" {
          loadBalancer = {
            servers = [ { url = "https://${address}"; } ];
            serversTransport = "peer-${peer}";
          };
        }
      ) cfg.peers;
      peerTransports = lib.mapAttrs' (
        peer: _:
        lib.nameValuePair "peer-${peer}" {
          serverName = (peerPodmanContainers peer).traefik.traefik.serviceHost;
        }
      ) cfg.peers;
    in
    {

      options.dafos.services.traefik = {
        enable = mkEnableOption "Whether or not to configure traefik.";
        base-url = opt types.str "daftdaf.dev" "The base url";

        # For apps that cannot be served on a second hostname. norish's OIDC
        # callback always lands on AUTH_URL, but better-auth's state cookie was set
        # on the host the login started from, so a login from an alias fails with
        # state_mismatch.
        redirects = opt (types.attrsOf (
          types.submodule {
            options = {
              to = opt types.str null "Subdomain the alias redirects to.";
              expose =
                opt types.bool false
                  "Whether the alias is reachable from outside the LAN/tailnet. Match the target.";
            };
          }
        )) { } "Subdomain aliases, keyed by alias, that redirect to another subdomain.";

        nativeRouters.enable = mkEnableOption "the routers to dafoltop's native services (Immich, Home Assistant, zone configurator, zigbee2mqtt)";

        dashboardAuth =
          opt types.bool true
            "Whether the Traefik dashboard sits behind Authelia forwardAuth (needs the authelia stack on the same host).";

        peers =
          opt (types.attrsOf types.str) { }
            "Other hosts running their own rootless Traefik, by name -> LAN address: every hostname they route is relayed to them from here.";

        routedHosts = mkOption {
          type = types.attrsOf (types.submodule { options.expose = opt types.bool false "Public route."; });
          internal = true;
          default = { };
          description = ''
            Every hostname this Traefik routes to a container, read from each
            container's router rule, so aliases added to a rule count too
            (kaneo). What peers relay (traefik `peers`) and resolve to this
            host (blocky `peers`).
          '';
        };
      };

      config = mkIf cfg.enable {
        dafos.services.traefik.routedHosts =
          let
            routed = lib.filterAttrs (_: c: c.traefik.name != null) config.services.podman.containers;
            # nps names the router after the container, not `traefik.name`.
            rules =
              c:
              lib.attrValues (
                lib.filterAttrs (k: _: builtins.match "traefik\\.http\\.routers\\.[^.]+\\.rule" k != null) c.labels
              );
            hostsOf =
              c:
              lib.unique (
                lib.concatMap (
                  r: lib.concatLists (lib.filter lib.isList (builtins.split "Host\\(`([^`]+)`\\)" r))
                ) (rules c)
              );
          in
          lib.foldl' (
            acc: c:
            acc
            // lib.genAttrs (hostsOf c) (_: {
              inherit (c) expose;
            })
          ) { } (lib.attrValues routed)
          # Redirect aliases are file routers, not container labels.
          // lib.mapAttrs' (
            alias: r: lib.nameValuePair "${alias}.${cfg.base-url}" { inherit (r) expose; }
          ) cfg.redirects;

        sops.secrets."cloudflare-api-token" = {
          sopsFile = inputs.self + "/secrets/dafoltop/cloudflare.yaml";
        };

        # nps gives Traefik a network alias for every hostname its stacks route,
        # so containers reach it over the podman network. The hand-written routers
        # below (native services) get none, and containers then reached them via
        # dafoltop's tailnet address
        services.podman.containers.traefik.extraConfig.Container.NetworkAlias =
          mkIf cfg.nativeRouters.enable
            (
              map (sub: "${sub}.${cfg.base-url}") [
                "immich"
                "photos"
                "photo"
                "home"
                "zones"
                "z2m"
              ]
            );

        nps.stacks.traefik = {
          enable = true;
          domain = cfg.base-url;
          geoblock.allowedCountries = [ "FR" ];

          dynamicConfig.http = {
            routers = nonEmpty (
              lib.optionalAttrs cfg.nativeRouters.enable {
                immich-nix = {
                  # Every hostname here needs its redirect_uris in the authelia
                  # immich client.
                  rule = "Host(`immich.${cfg.base-url}`) || Host(`photos.${cfg.base-url}`) || Host(`photo.${cfg.base-url}`)";
                  service = "immich-service";
                  inherit entryPoints;
                  middlewares = [ "public@file" ];
                  tls.certResolver = "letsencrypt"; # NPS default resolver name
                };
                home-assistant-nix = {
                  rule = "Host(`home.${cfg.base-url}`)";
                  service = "home-assistant-service";
                  inherit entryPoints;
                  middlewares = [ "public@file" ];
                  tls.certResolver = "letsencrypt"; # NPS default resolver name
                };
                zone-configurator-nix = {
                  rule = "Host(`zones.${cfg.base-url}`)";
                  service = "zone-configurator-service";
                  inherit entryPoints;
                  # The zone configurator has no authentication of its own and can
                  # rewrite sensor zones and push OTA firmware, so keep it on the
                  # same source-IP gate as zigbee2mqtt.
                  middlewares = [ "private@file" ];
                  tls.certResolver = "letsencrypt"; # NPS default resolver name
                };
                zigbee2mqtt-nix = {
                  rule = "Host(`z2m.${cfg.base-url}`)";
                  service = "zigbee2mqtt-service";
                  inherit entryPoints;
                  # zigbee2mqtt has no authentication of its own and can pair/remove
                  # devices on the mesh, so keep it source-IP gated. Traefik matches
                  # routers on the Host header, not on the address the client dialled,
                  # so a public DNS record pointing elsewhere is not a control here.
                  middlewares = [ "private@file" ];
                  tls.certResolver = "letsencrypt"; # NPS default resolver name
                };
              }
              // lib.mapAttrs' (
                alias: r:
                lib.nameValuePair "redirect-${alias}" {
                  rule = "Host(`${alias}.${cfg.base-url}`)";
                  # The redirect middleware always answers first, but a router still
                  # has to name a service.
                  service = "noop@internal";
                  inherit entryPoints;
                  middlewares = [
                    (if r.expose then "public@file" else "private@file")
                    "redirect-${alias}@file"
                  ];
                  tls.certResolver = "letsencrypt"; # NPS default resolver name
                }
              ) cfg.redirects
              // peerRouters
            );

            middlewares = {
              # nps ships `private` as an RFC1918-only ipAllowList; the tailnet lives in
              # CGNAT space, so without this our own tailscale clients get a 403.
              ipwhitelist-internal.ipAllowList.sourceRange = lib.mkAfter [ "100.64.0.0/10" ];

              # Traefik was returning no content-encoding at all, even when the client
              # offered gzip/br: the glance dashboard shipped 72kB of JSON per page
              # load that gzips to 6kB. mkBefore puts this outermost so it wraps the
              # response from the rest of the chain.
              compress.compress = { };
              public.chain.middlewares = lib.mkBefore [ "compress" ];

              # nps defaults this to average/burst 100, which is below what a
              # code-split SPA needs for a *cold* load: BookOrbit ships one chunk
              # per lucide icon and asks for 181 files at once, so everything past
              # the 100th came back 429. The failure is unrecognisable from the
              # browser -- Traefik's 429 carries no Content-Type and
              # `security-headers` sets `X-Content-Type-Options: nosniff`, so
              # Firefox rejects each module script with `disallowed MIME type ("")`
              # and the page just renders black. Only ever seen with an empty cache
              # (private window, first visit), which is what makes it look random.
              #
              # The bucket is per client IP (Traefik's default sourceCriterion), so
              # this bounds one browser's page load, not aggregate traffic.
              public-ratelimit.rateLimit = {
                average = lib.mkForce 250;
                burst = lib.mkForce 500;
              };
            }
            // lib.mapAttrs' (
              alias: r:
              lib.nameValuePair "redirect-${alias}" {
                redirectRegex = {
                  regex = "^https?://[^/]+/(.*)";
                  replacement = "https://${r.to}.${cfg.base-url}/\${1}";
                };
              }
            ) cfg.redirects;

            services = nonEmpty (
              lib.optionalAttrs cfg.nativeRouters.enable {
                immich-service = {
                  loadBalancer.servers = [
                    {
                      url = "http://host.containers.internal:2283";
                    }
                  ];
                };
                home-assistant-service = {
                  loadBalancer.servers = [
                    {
                      url = "http://host.containers.internal:8123";
                    }
                  ];
                };
                zone-configurator-service = {
                  loadBalancer.servers = [
                    {
                      url = "http://host.containers.internal:42069";
                    }
                  ];
                };
                zigbee2mqtt-service = {
                  loadBalancer.servers = [
                    {
                      url = "http://host.containers.internal:8090";
                    }
                  ];
                };
              }
              // peerServices
            );

            serversTransports = nonEmpty peerTransports;
          };

          containers.traefik = {
            extraConfig.Container.DNS = "1.1.1.1";

            # The dashboard (traefik.) maps every router, middleware and backend,
            # and only sat behind the source-IP gate. Put it behind Authelia too.
            forwardAuth.enable = cfg.dashboardAuth;
          };

          extraEnv = {
            CF_DNS_API_TOKEN.fromFile = config.sops.secrets."cloudflare-api-token".path;
          };
        };
      };
    };
}
