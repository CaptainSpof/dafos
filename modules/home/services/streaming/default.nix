{
  lib,
  config,
  namespace,
  pkgs,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) enabled;
  inherit (lib.${namespace}) mkOpt mkBoolOpt;

  cfg = config.${namespace}.services.streaming;

  lldapStack = config.nps.stacks.lldap;
  jellyfinOidc = config.nps.stacks.streaming.jellyfin.oidc;

  plugins = import ./jellyfin-plugins.nix { inherit lib pkgs; };

  jellyfinPluginDir = "${config.nps.storageBaseDir}/streaming/jellyfin/data/plugins";

  # What the plugins directory should contain: the 12.x set, plus whichever of
  # the two auth plugins is switched on.
  managedPlugins =
    plugins.all12
    ++ lib.optional cfg.jellyfin.ldapAuth.enable plugins.ldap-auth
    ++ lib.optional jellyfinOidc.enable plugins.sso-auth;

  # lldap's LDAP tree: users under `ou=people`, groups under `ou=groups`.
  userBaseDn = "ou=people,${lldapStack.baseDn}";
  groupDn = group: "cn=${group},ou=groups,${lldapStack.baseDn}";

  # The same two groups nps already creates for the OIDC half, so the LDAP and
  # SSO login paths cannot drift apart on who is allowed in and who is admin.
  ldapAuthConfigSource = pkgs.writeText "ldap-auth-config" (
    import ./ldap-auth-config.nix {
      ldapServer = "lldap";
      ldapPort = 3890;

      # `readonly` already exists in lldap's `lldap_strict_readonly` group and
      # is exactly a bind account; no new user and no new secret. The path is
      # declared by the lldap module, which lands in the same home config.
      # `CN=` rather than `uid=`: that is lldap's own bind-DN form, and it is
      # what Authelia already binds with against this same directory.
      bindDn = "CN=readonly,${userBaseDn}";
      bindPasswordFile = config.sops.secrets."lldap/users/readonly-password".path;

      inherit userBaseDn;
      loginFilter = "(|(memberOf=${groupDn jellyfinOidc.userGroup})(memberOf=${groupDn jellyfinOidc.adminGroup}))";
      adminFilter = "(memberOf=${groupDn jellyfinOidc.adminGroup})";
      passwordResetUrl = config.nps.containers.lldap.traefik.serviceUrl;
    }
  );

  # Validate at build time. Jellyfin does not report a malformed plugin config:
  # `BasePlugin.LoadConfiguration` catches the deserialization exception, falls
  # back to a default-constructed object and *saves it over the file*, so the
  # only symptom is a settings page full of `contoso.com` and a login path that
  # silently does nothing. A stray `--` inside an XML comment shipped exactly
  # that on 2026-09-16.
  #
  # The gomplate expressions are blanked first: `{{ ... }}` is not XML, and the
  # secret it reads is not in the store anyway.
  ldapAuthConfig =
    pkgs.runCommand "ldap-auth-config-checked"
      {
        nativeBuildInputs = [ pkgs.libxml2 ];
      }
      ''
        sed 's|{{[^}]*}}|PLACEHOLDER|g' ${ldapAuthConfigSource} > checked.xml
        xmllint --noout checked.xml
        cp ${ldapAuthConfigSource} "$out"
      '';

  # Transcoding settings pinned over the stateful encoding.xml. The rest of the
  # file stays Jellyfin's to manage from the dashboard; only these elements are
  # forced back, on every container start, so a dashboard edit or a major
  # upgrade's silent reset-to-defaults cannot quietly undo them.
  #
  # - HardwareAccelerationType / QsvDevice: the 12.x migration reset these to
  #   `none` and blank. The box has two render nodes, renderD128 (i915) and
  #   renderD129 (nouveau), so QSV must name the Intel one explicitly.
  # - EnableThrottling: without it ffmpeg reads the source as fast as the link
  #   allows. A 4K remux over the Freebox SMB share saturated dafoltop's 100
  #   Mbit NIC on 2026-09-27, and DNS (blocky), ping and SSH all timed out
  #   behind it.

  # Updates only elements whose value differs, so an already-correct file is
  # left byte-for-byte alone. xmlstarlet refuses malformed input, and that is
  # deliberate: a broken file makes Jellyfin reset the whole thing, so better
  # to fail the start loudly than to patch around it. A missing file (first
  # start) is skipped; Jellyfin writes its defaults and the next start pins.

  # Transcoding settings pinned over the stateful encoding.xml. The rest of the
  # file stays Jellyfin's to manage from the dashboard; only these elements are
  # forced back, on every container start, so a dashboard edit or a major
  # upgrade's silent reset-to-defaults cannot quietly undo them.
  #
  # - HardwareAccelerationType / QsvDevice: the 12.x migration reset these to
  #   `none` and blank. The box has two render nodes, renderD128 (i915) and
  #   renderD129 (nouveau), so QSV must name the Intel one explicitly.
  # - EnableThrottling: without it ffmpeg reads the source as fast as the link
  #   allows. A 4K remux over the Freebox SMB share saturated dafoltop's 100
  #   Mbit NIC on 2026-09-27, and DNS (blocky), ping and SSH all timed out
  #   behind it.
  # - ThrottleDelaySeconds: how far ffmpeg may run ahead before pausing, read at
  #   full link speed. 300 (up from the 180 default) is sized for a gigabit
  #   NIC; on the 100 Mbit one it saturates the link ~4 min per start or seek.
  jellyfinEncoding = {
    HardwareAccelerationType = "qsv";
    QsvDevice = "/dev/dri/renderD128";
    EnableThrottling = "true";
    ThrottleDelaySeconds = "300";
  };

  jellyfinEncodingXml = "${config.nps.storageBaseDir}/streaming/jellyfin/encoding.xml";

  # Updates only elements whose value differs, so an already-correct file is
  # left byte-for-byte alone. xmlstarlet refuses malformed input, and that is
  # deliberate: a broken file makes Jellyfin reset the whole thing, so better
  # to fail the start loudly than to patch around it. A missing file (first
  # start) is skipped; Jellyfin writes its defaults and the next start pins.
  pinJellyfinEncoding = pkgs.writeShellApplication {
    name = "pin-jellyfin-encoding";
    runtimeInputs = [ pkgs.xmlstarlet ];
    text = ''
      f=${lib.escapeShellArg jellyfinEncodingXml}
      [ -e "$f" ] || exit 0
    ''
    + lib.concatStrings (
      lib.mapAttrsToList (name: value: ''
        xpath=/EncodingOptions/${name}
        if [ "$(xmlstarlet sel -t -v "count($xpath)" "$f")" = 0 ]; then
          xmlstarlet ed -L -s /EncodingOptions -t elem -n ${name} -v ${lib.escapeShellArg value} "$f"
        elif [ "$(xmlstarlet sel -t -v "$xpath" "$f")" != ${lib.escapeShellArg value} ]; then
          xmlstarlet ed -L -u "$xpath" -v ${lib.escapeShellArg value} "$f"
        fi
      '') jellyfinEncoding
    );
  };

  brandingXml = pkgs.writeText "branding.xml" ''
    <?xml version="1.0" encoding="utf-8"?>
    <BrandingOptions xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
      <LoginDisclaimer>&lt;form action="${config.nps.containers.jellyfin.traefik.serviceUrl}/sso/OID/start/authelia"&gt;
        &lt;button class="raised block emby-button button-submit"&gt;
        Se connecter avec Authelia
        &lt;/button&gt;
        &lt;/form&gt;
      </LoginDisclaimer>
      <CustomCss>
      @import url("https://cdn.jsdelivr.net/gh/lscambo13/ElegantFin@main/Theme/ElegantFin-jellyfin-theme-build-latest-minified.css"); 
      a.raised.emby-button {
        padding: 0.9em 1em;
        color: inherit !important;
      }
      .disclaimerContainer {
        display: block;
      }
      </CustomCss>
      <SplashscreenEnabled>true</SplashscreenEnabled>
    </BrandingOptions>
  '';
in
{

  options.${namespace}.services.streaming = {
    enable = mkEnableOption "Whether or not to configure streaming.";
    base-url = mkOpt types.str "streaming.daftdaf.dev" "The base url";

    jellyfin.ldapAuth.enable = mkBoolOpt true "Whether to authenticate Jellyfin against lldap with the official LDAP Authentication plugin.";
  };

  config = mkIf cfg.enable {
    sops.secrets = {
      "qui/authelia/client-secret".sopsFile = lib.snowfall.fs.get-file "secrets/dafoltop/streaming.yaml";
      "jellyfin/authelia/client-secret".sopsFile =
        lib.snowfall.fs.get-file "secrets/dafoltop/streaming.yaml";
      "gluetun/wg-pk".sopsFile = lib.snowfall.fs.get-file "secrets/dafoltop/streaming.yaml";
      "gluetun/wg-address".sopsFile = lib.snowfall.fs.get-file "secrets/dafoltop/streaming.yaml";
    };

    # Plugin directories have to be writable -- Jellyfin rewrites each plugin's
    # own meta.json when it first loads it, and fails *startup* if it cannot --
    # so the pinned store copies are materialised here rather than bind-mounted.
    # Ordered before `reloadSystemd` so the files are in place before the
    # container is restarted.
    home.activation.jellyfinPlugins = config.lib.dag.entryBefore [ "reloadSystemd" ] (
      lib.concatStringsSep "\n" (map (plugins.install jellyfinPluginDir) managedPlugins)
    );

    nps = {
      externalStorageBaseDir = "/mnt/data/yahrr";
      stacks = {
        # nps registers the Jellyfin client with the bare one_factor policy, so
        # Authelia would issue tokens to any lldap user and leave the refusal to
        # the SSO plugin's role check. Gate it on the same groups up front,
        # like the home-assistant and immich clients.
        authelia = mkIf jellyfinOidc.enable {
          oidc.clients.jellyfin.authorization_policy = lib.mkForce "jellyfin";
          settings.identity_providers.oidc.authorization_policies.jellyfin = {
            default_policy = "deny";
            rules = [
              {
                policy = config.nps.stacks.authelia.defaultAllowPolicy;
                subject = [
                  "group:${jellyfinOidc.adminGroup}"
                  "group:${jellyfinOidc.userGroup}"
                ];
              }
            ];
          };
        };

        streaming = {
          enable = true;

          containers = {
            jellyfin = {
              expose = true;

              # The LDAP and SSO plugin configs are rendered from the lldap
              # readonly password and the OIDC client secret at start; restart
              # when either file is rotated (see the authelia module).
              extraConfig.Unit.X-Secrets-Hash =
                lib.concatMapStringsSep " "
                  (f: builtins.hashFile "sha256" (lib.snowfall.fs.get-file "secrets/dafoltop/${f}.yaml"))
                  [
                    "lldap"
                    "streaming"
                  ];

              # The image pin is upstream's again: nps carries 12.1 and a
              # renovate regex for linuxserver's `version-<v>ubu<n>` tag shape,
              # which is what its old rule could not match.
              #
              # But that tag *moves* -- `12.1ubu2604-ls49` and `-ls50` are
              # distinct builds of the same Jellyfin, and `version-12.1ubu2604`
              # follows the newer one -- so on the default `registry` policy the
              # Sunday 00:00 pull would roll linuxserver rebuilds unattended
              # into a container holding a database. `local` keeps it on the
              # image already on disk and moves upgrades onto a rebuild, where
              # they are a reviewable diff. Same reasoning as the data-bearing
              # containers in the grimmory module.
              autoUpdate = "local";

              # Merges with nps' own ExecStartPre list (volume dirs, templates).
              extraConfig.Service.ExecStartPre = [ (lib.getExe pinJellyfinEncoding) ];

              # `volumeMap`, not `volumes`. nps builds `volumes` as
              #
              #   mkMerge [ (attrValues volumeMap) (mkAfter <template/fileEnv mounts>) ]
              #
              # so forcing `volumes` here silently discarded the second branch --
              # which is how the rendered SSO-Auth.xml and LDAP-Auth.xml were
              # never actually reaching the container, leaving both plugins on
              # their built-in defaults. Forcing the map instead replaces nps'
              # own entries (dropping its single `media` mount for the two paths
              # below) and leaves the generated configs to append.
              volumeMap = lib.mkForce {
                movies = "/mnt/data/Movies:/movies";
                shows = "/mnt/data/Shows:/shows";
                config = "${config.nps.storageBaseDir}/streaming/jellyfin:/config";
                brandingXml = "${brandingXml}:/config/branding.xml";
              };

              # Ours only -- `mkForce` drops nps' own entry for SSO-Auth.xml.
              #
              # That entry never actually reached the container (the `volumes`
              # mkForce that used to be above discarded it), so the working SSO
              # configuration is the stateful file, and it holds one thing no
              # template can: `CanonicalLinks`, the Authelia-subject-to-Jellyfin-user
              # account links. Mounting the template would silently detach every
              # linked account.
              #
              # That is now the *only* reason. nps a5f7e7f added
              # `DisablePushedAuthorization` to its template, and
              # `UseClientSecretBasic` is a plain bool defaulting to false,
              # which is the live value -- so if account linking ever moves out
              # of this file, the override can go.
              #
              # LDAP-Auth has no equivalent: its `LdapUsers` is a uid-to-guid
              # cache the plugin rebuilds, which is why its config can be
              # generated and this one cannot.
              templateMount = lib.mkForce (
                lib.optional cfg.jellyfin.ldapAuth.enable {
                  templatePath = ldapAuthConfig;
                  destPath = "/config/data/plugins/configurations/LDAP-Auth.xml";
                }
              );
            };
            sonarr = {
              volumes = lib.mkForce [
                "/mnt/data/Shows:/media"
                "/mnt/data/yahrr:/yahrr"
                "${config.nps.storageBaseDir}/streaming/sonarr:/config"
              ];
            };
            radarr = {
              volumes = lib.mkForce [
                "/mnt/data/Movies:/media"
                "/mnt/data/yahrr:/yahrr"
                "${config.nps.storageBaseDir}/streaming/radarr:/config"
              ];
            };
          };

          jellyfin = {
            enable = true;

            oidc = {
              enable = true;
              clientSecretFile = config.sops.secrets."jellyfin/authelia/client-secret".path;
            };
          };
          bazarr = enabled;
          profilarr = enabled;
          radarr = enabled;
          seerr = enabled;
          sonarr = enabled;
        };

        # nps e44f684 split gluetun/qbittorrent/qui out of the streaming stack
        # into a standalone `qbittorrent` stack (and prowlarr + flaresolverr
        # into `prowlarr`). `streaming.useQbittorrent` / `.useProwlarr` default
        # to true and enable those stacks on the streaming network, so only
        # their settings move here.
        qbittorrent = {
          containers = {
            gluetun = {
              ports = [ "8888:8888" ];
            };
            qbittorrent = {
              volumes = lib.mkForce [
                "/mnt/data/yahrr:/yahrr"
                # Its own directory, not radarr's: sharing it handed qbittorrent
                # radarr's database and API key.
                "${config.nps.storageBaseDir}/qbittorrent/qbittorrent:/config"
              ];
            };
            qui.expose = true;
          };

          gluetun = {
            enable = true;

            vpnProvider = "protonvpn";
            wireguardPrivateKeyFile = config.sops.secrets."gluetun/wg-pk".path;
            wireguardPresharedKeyFile = pkgs.writeText "wg-psk-empty" "";
            wireguardAddressesFile = config.sops.secrets."gluetun/wg-address".path;
          };
          qui = {
            enable = true;

            oidc = {
              enable = true;
              clientSecretFile = config.sops.secrets."qui/authelia/client-secret".path;
            };
          };
        };
      };
    };
  };
}
