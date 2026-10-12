{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkIf
    optionalAttrs
    types
    ;
  inherit (lib.${namespace}) mkOpt mkBoolOpt;

  cfg = config.${namespace}.services.immich;

  mediaRoot = "/var/lib/immich";

  # IMMICH_MEDIA_LOCATION stays , so no path stored in the database
  # changes: the data directories are bind-mounted back onto it. `nofail` keeps a
  # missing disk from stopping the boot; immich-server requires the mounts (below)
  # and fails, and alerts, instead of writing under an empty mount point.
  bindDirs =
    base: dirs:
    lib.listToAttrs (
      map (
        d:
        lib.nameValuePair "${mediaRoot}/${d}" {
          device = "${base}/${d}";
          fsType = "none";
          options = [
            "bind"
            "nofail"
          ];
        }
      ) dirs
    );

  boundDirs =
    optionalAttrs (cfg.originalsPath != null) (
      bindDirs cfg.originalsPath [
        "upload"
        "library"
      ]
    )
    // optionalAttrs (cfg.derivedPath != null) (
      bindDirs cfg.derivedPath [
        "thumbs"
        "encoded-video"
        "backups"
      ]
    );
in
{

  options.${namespace}.services.immich = {
    enable = mkEnableOption "Whether or not to configure immich.";
    base-url = mkOpt types.str "immich.daftdaf.dev" "The base url";
    port = mkOpt types.int 2283 "The port";

    originalsPath = mkOpt (types.nullOr types.str) null ''
      Where the original photos live (`upload/` and `library/`), bind-mounted over
      `/var/lib/immich`. Must be on a disk that is not the root: Immich is tied to
      the mounts, so it refuses to start when the disk is missing instead of
      writing into an empty directory on the root. The directories must already
      exist there (create them by hand while migrating, never with tmpfiles: on a
      missing disk that would recreate them on the root).
    '';

    derivedPath = mkOpt (types.nullOr types.str) null ''
      Where the regenerable data lives (`thumbs/`, `encoded-video/`, `backups/`),
      bind-mounted over `/var/lib/immich`. Thumbnails grow with the library
      (~0.7 MB per photo), so a large library needs a bigger, but still fast, disk
      than the root. immich-server runs with ProtectHome=yes, which hides /home
      from the service but not a bind mount of a directory under it (checked on
      dafoltop with systemd-run before the first use).
    '';

    originalsMountUnit = mkOpt types.str "mnt-data.mount" ''
      The mount unit of the disk behind originalsPath. immich-server is wanted by
      it, so it starts again by itself when the disk comes back after a drop
      (Requires= propagates a stop, never a start).
    '';

    oidc = {
      # Immich runs as a native NixOS service here, but the identity provider
      # (Authelia) is an nps stack in daf's home-manager config. The client is
      # registered there by hand, mirroring what `nps.stacks.immich.oidc` does
      # for the containerised stack; both halves share the same sops secret.
      enable = mkBoolOpt true "Whether or not to configure OIDC login through Authelia.";
      issuer-url = mkOpt types.str "https://auth.daftdaf.dev" "The Authelia OIDC issuer url";
      client-id = mkOpt types.str "immich" "The OIDC client id registered in Authelia";
    };
  };

  config = mkIf cfg.enable {

    users.groups.yahrr.members = [ "immich" ];

    fileSystems = boundDirs;

    systemd.services.immich-server = mkIf (boundDirs != { }) {
      unitConfig.RequiresMountsFor = lib.attrNames boundDirs;
      wantedBy = lib.optional (cfg.originalsPath != null) cfg.originalsMountUnit;
    };

    sops.secrets = mkIf cfg.oidc.enable {
      "immich/authelia/client-secret" = {
        sopsFile = lib.snowfall.fs.get-file "secrets/dafoltop/immich.yaml";
        restartUnits = [ "immich-server.service" ];
      };
    };

    services.immich = {
      enable = true;
      redis.enable = true;
      machine-learning.enable = true;
      inherit (cfg) port;
      # Still bound wide: rootless Traefik and immich-kiosk reach it through
      # pasta's host.containers.internal, which lands on the host's own
      # address over `lo`. Everything else goes through Traefik.
      host = "0.0.0.0";
      openFirewall = false;

      settings = {
        server.externalDomain = "https://${cfg.base-url}";

        oauth = optionalAttrs cfg.oidc.enable {
          enabled = true;
          autoLaunch = false;
          autoRegister = true;
          buttonText = "Login with Authelia";
          clientId = cfg.oidc.client-id;
          # Read at unit start through systemd LoadCredential, so the secret
          # never lands in the nix store.
          clientSecret._secret = config.sops.secrets."immich/authelia/client-secret".path;
          # null = unlimited. 0 means 0 GiB: every upload then fails with "Quota
          # has been exceeded!" for a new user whose lldap entry has no immich-quota.
          defaultStorageQuota = null;
          issuerUrl = cfg.oidc.issuer-url;
          mobileOverrideEnabled = false;
          mobileRedirectUri = "";
          scope = "openid profile email immich";
          storageLabelClaim = "preferred_username";
          storageQuotaClaim = "immich_quota";
          roleClaim = "immich_role";
          timeout = 30000;
          tokenEndpointAuthMethod = "client_secret_post";
        };
      };
    };

    services.caddy.virtualHosts = {
      "${cfg.base-url}".extraConfig = ''
        reverse_proxy "http://0.0.0.0:${toString cfg.port}"
        import cloudflare
      '';
      "photos.daftdaf.dev".extraConfig = ''
        reverse_proxy "http://0.0.0.0:${toString cfg.port}"
        import cloudflare
      '';
    };
  };
}
