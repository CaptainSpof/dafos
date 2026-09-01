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
in
{

  options.${namespace}.services.immich = {
    enable = mkEnableOption "Whether or not to configure immich.";
    base-url = mkOpt types.str "immich.daftdaf.dev" "The base url";
    port = mkOpt types.int 2283 "The port";

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

    sops.secrets = mkIf cfg.oidc.enable {
      "immich/authelia/client-secret".sopsFile = lib.snowfall.fs.get-file "secrets/daf/immich.yaml";
    };

    services.immich = {
      enable = true;
      redis.enable = true;
      machine-learning.enable = true;
      inherit (cfg) port;
      host = "0.0.0.0";
      openFirewall = true;

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
          defaultStorageQuota = 0;
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
