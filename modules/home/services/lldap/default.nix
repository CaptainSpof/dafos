{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkIf
    types
    mkOption
    ;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.services.lldap;

  # Avatars are consumed twice, in two incompatible shapes:
  #
  #   * LLDAP's bootstrap script wants a *file inside its own container*, which
  #     becomes the binary `jpegPhoto`/`avatar` attribute shown in its web UI.
  #   * Authelia's `picture` claim wants a *URL* (see the authelia module), which
  #     is what downstream OIDC apps such as Immich actually fetch. Authelia
  #     cannot read the binary attribute, so the same jpeg is also served over
  #     HTTP by the `avatars` container below and referenced by the `picture`
  #     custom attribute.
  #
  # Both halves are fed from this one attrset, so adding an avatar for another
  # user is a single entry here plus `avatar_url`/`picture` on that user.
  avatars = {
    daf = ./avatars/daf.jpg;
  };

  # Symlinks would dangle inside the containers, so materialise real copies.
  # Interpolate the sources directly rather than via `escapeShellArg`: that
  # runs `toString` on the path, which yields a bare filesystem path with no
  # string context, so the jpeg never gets copied into the store.
  avatarRoot = pkgs.runCommand "lldap-avatars" { } ''
    mkdir -p "$out"
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (id: src: ''cp ${src} "$out/${id}.jpg"'') avatars)}
  '';

  avatarDir = "/bootstrap/avatars";

  # `avatar_url` rather than `avatar_file`, even though the file is right there
  # in the container: nps declares the user submodule's freeform type as a bare
  # `oneOf` instead of an `attrsOf`, so a user may carry exactly one undeclared
  # attribute before the module system reports the whole user as defined twice.
  # `picture` below spends that budget, so the avatar has to travel through a
  # declared option. The bootstrap script just curls this, and Alpine's curl
  # keeps the `file` protocol, so it stays a local read with no dependency on
  # the `avatars` container being up.
  avatarFileUrl = id: "file://${avatarDir}/${id}.jpg";
  avatarUrl = id: "https://${cfg.avatarSubDomain}.${cfg.domain}/${id}.jpg";

  users = with config.nps.stacks; {
    readonly = {
      id = "readonly";
      displayName = "readonly";
      password_file = config.sops.secrets."lldap/users/readonly-password".path;
      email = "readonly@${cfg.domain}";
      groups = [ lldap.readOnlyGroup ];
    };
    daf = {
      id = "daf";
      displayName = "daf";
      password_file = config.sops.secrets."lldap/users/daf-password".path;
      email = "dafonseca.cedric@gmail.com";
      avatar_url = avatarFileUrl "daf";
      picture = avatarUrl "daf";
      groups = [
        lldap.adminGroup
        streaming.jellyfin.oidc.adminGroup

        "immich_admin"

        # No group-based admin access supported yet, just user-roles
        "home-assistant_user"
        bar-assistant.oidc.userGroup
        grimmory.oidc.userGroup
        donetick.oidc.userGroup
        kaneo.oidc.userGroup
        karakeep.oidc.userGroup
        norish.oidc.userGroup
        papra.oidc.userGroup
        reactive-resume.oidc.userGroup
        streaming.qui.oidc.userGroup
        sparky-fitness.oidc.userGroup
      ];
    };
    cedric = {
      id = "cedric";
      displayName = "cedric";
      password_file = config.sops.secrets."lldap/users/cedric-password".path;
      email = "cedric@${cfg.domain}";
      groups = [
        lldap.adminGroup

        # No group-based admin access supported yet, just user-roles
        "home-assistant_user"
        streaming.qui.oidc.userGroup
        grimmory.oidc.userGroup
        papra.oidc.userGroup
        donetick.oidc.userGroup
        norish.oidc.userGroup
      ];
    };
    joaquim = {
      id = "joaquim";
      displayName = "joaquim";
      password_file = config.sops.secrets."lldap/users/joaquim-password".path;
      email = "joaquim@${cfg.domain}";
      groups = [
        lldap.adminGroup

        # No group-based admin access supported yet, just user-roles
        streaming.qui.oidc.userGroup
        grimmory.oidc.userGroup
        norish.oidc.userGroup
      ];
    };
    test = {
      id = "test";
      displayName = "test";
      password_file = config.sops.secrets."lldap/users/test-password".path;
      email = "test@${cfg.domain}";
      groups = [
        # No group-based admin access supported yet, just user-roles
        streaming.qui.oidc.userGroup
        grimmory.oidc.userGroup
        papra.oidc.userGroup
        donetick.oidc.userGroup
      ];
    };
  };

in
{
  options.${namespace}.services.lldap = {
    enable = mkEnableOption "Whether or not to configure lldap.";
    domain = mkOpt types.str "daftdaf.dev" "The base domain url";
    avatarSubDomain =
      mkOpt types.str "avatars"
        "Subdomain the user avatars are served from, for Authelia's `picture` claim.";
    lldapUsers = mkOption {
      type = types.attrs;
      default = users;
      description = "Central definition of LLDAP users";
    };
  };

  config = mkIf cfg.enable {
    sops.secrets = {
      "lldap/admin-password".sopsFile = lib.snowfall.fs.get-file "secrets/daf/lldap.yaml";
      "lldap/jwt-secret".sopsFile = lib.snowfall.fs.get-file "secrets/daf/lldap.yaml";
      "lldap/key-seed".sopsFile = lib.snowfall.fs.get-file "secrets/daf/lldap.yaml";
      "lldap/users/daf-password".sopsFile = lib.snowfall.fs.get-file "secrets/daf/lldap.yaml";
      "lldap/users/cedric-password".sopsFile = lib.snowfall.fs.get-file "secrets/daf/lldap.yaml";
      "lldap/users/joaquim-password".sopsFile = lib.snowfall.fs.get-file "secrets/daf/lldap.yaml";
      "lldap/users/readonly-password".sopsFile = lib.snowfall.fs.get-file "secrets/daf/lldap.yaml";
      "lldap/users/test-password".sopsFile = lib.snowfall.fs.get-file "secrets/daf/lldap.yaml";
    };

    services.podman.containers = {
      # Bind-mount the jpegs the bootstrap script points `avatar_url` at.
      lldap.volumeMap.avatars = "${avatarRoot}:${avatarDir}:ro";

      # Authelia's `picture` attribute is a URL rather than a blob, so the same
      # jpegs are also served as plain static files. Public on purpose: Immich
      # downloads the picture server-side, but other clients render it straight
      # from the browser, which may well be off-LAN. nginx-unprivileged serves
      # its docroot on 8080 with no config of our own, and has no autoindex, so
      # only the exact `<user>.jpg` paths are reachable.
      avatars = {
        image = "docker.io/nginxinc/nginx-unprivileged:1.30.4-alpine";
        volumeMap.avatars = "${avatarRoot}:/usr/share/nginx/html:ro";
        port = 8080;
        traefik = {
          name = "avatars";
          subDomain = cfg.avatarSubDomain;
        };
        expose = true;
      };
    };

    nps.stacks = {
      lldap = {
        enable = true;

        baseDn = "DC=daftdaf,DC=dev";

        adminPasswordFile = config.sops.secrets."lldap/admin-password".path;
        jwtSecretFile = config.sops.secrets."lldap/jwt-secret".path;
        keySeedFile = config.sops.secrets."lldap/key-seed".path;

        bootstrap = {
          users = cfg.lldapUsers;
          groups.home-assistant_user = { };

          # Immich runs as a native NixOS service, so its groups and the quota
          # attribute are declared here instead of by `nps.stacks.immich`.
          groups.immich_admin = { };
          groups.immich_user = { };
          userSchemas.immich-quota.attributeType = "INTEGER";

          # LLDAP's own `avatar` is a jpeg blob and Authelia can only read a URL,
          # so the avatar's public address is stored alongside it as a plain
          # string and mapped to the `picture` claim by the authelia module.
          userSchemas.picture.attributeType = "STRING";
        };
      };
    };
  };
}
