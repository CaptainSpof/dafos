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
  ldapAuthConfig = pkgs.writeText "ldap-auth-config" (
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
      "qui/authelia/client-secret".sopsFile = lib.snowfall.fs.get-file "secrets/daf/streaming.yaml";
      "jellyfin/authelia/client-secret".sopsFile = lib.snowfall.fs.get-file "secrets/daf/streaming.yaml";
      "gluetun/wg-pk".sopsFile = lib.snowfall.fs.get-file "secrets/daf/streaming.yaml";
      "gluetun/wg-address".sopsFile = lib.snowfall.fs.get-file "secrets/daf/streaming.yaml";
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
      externalStorageBaseDir = "/mnt/yahrr";
      stacks = {
        streaming = {
          enable = true;

          containers = {
            jellyfin = {
              expose = true;

              # nps pins 10.11.11 and will not move on its own: linuxserver
              # changed its tag shape to `12.1ubu2604-ls50` (it used to be a
              # bare `10.11.11`), so nps' renovate rule no longer matches the
              # 12.x line at all.
              #
              # One-way trip. 12.x migrates the database and upstream is
              # explicit that rolling back needs a full restore of
              # `${config.nps.storageBaseDir}/streaming/jellyfin`, and a full
              # library rescan is required afterwards to rebuild the
              # alternate-version links it drops on the way through.
              image = lib.mkForce "lscr.io/linuxserver/jellyfin:12.1ubu2604-ls50";

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
                movies = "/mnt/videos/Movies:/movies";
                shows = "/mnt/videos/Shows:/shows";
                config = "${config.nps.storageBaseDir}/streaming/jellyfin:/config";
                brandingXml = "${brandingXml}:/config/branding.xml";
              };

              # Ours only -- `mkForce` drops nps' own entry for SSO-Auth.xml.
              #
              # That entry never actually reached the container (the `volumes`
              # mkForce above discarded it), so the working SSO configuration is
              # the stateful file, and it has diverged from what nps generates:
              # it holds `CanonicalLinks` -- the Authelia-subject-to-Jellyfin-user
              # account links -- plus `DisablePushedAuthorization` and
              # `UseClientSecretBasic`, none of which the template reproduces.
              # Mounting it now would silently detach every linked account and
              # revert two settings Authelia login depends on.
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
                "/mnt/videos/Shows:/media"
                "/mnt/yahrr:/yahrr"
                "${config.nps.storageBaseDir}/streaming/sonarr:/config"
              ];
            };
            radarr = {
              volumes = lib.mkForce [
                "/mnt/videos/Movies:/media"
                "/mnt/yahrr:/yahrr"
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
                "/mnt/yahrr:/yahrr"
                "${config.nps.storageBaseDir}/streaming/radarr:/config"
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
