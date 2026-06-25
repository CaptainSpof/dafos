{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types mkOption;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.services.lldap;


  users = with config.nps.stacks; {
    readonly = {
      id = "readonly";
      displayName = "readonly";
      password_file = config.sops.secrets."lldap/users/readonly-password".path;
      email = "readonly@${cfg.domain}";
      groups = [lldap.readOnlyGroup];
    };
    daf = {
      id = "daf";
      displayName = "daf";
      password_file = config.sops.secrets."lldap/users/daf-password".path;
      email = "dafonseca.cedric@gmail.com";
      groups = [
        lldap.adminGroup
        streaming.jellyfin.oidc.adminGroup

        # No group-based admin access supported yet, just user-roles
        grimmory.oidc.userGroup
        donetick.oidc.userGroup
        karakeep.oidc.userGroup
        norish.oidc.userGroup
        papra.oidc.userGroup
        reactive-resume.oidc.userGroup
        streaming.qui.oidc.userGroup
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
        streaming.qui.oidc.userGroup
        grimmory.oidc.userGroup
        papra.oidc.userGroup
        donetick.oidc.userGroup
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
      lldapUsers =  mkOption {
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
        "lldap/users/readonly-password".sopsFile = lib.snowfall.fs.get-file "secrets/daf/lldap.yaml";
        "lldap/users/test-password".sopsFile = lib.snowfall.fs.get-file "secrets/daf/lldap.yaml";
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
          };
        };
      };
    };
  }
