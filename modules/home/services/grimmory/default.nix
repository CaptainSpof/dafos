{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types mkOption;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.services.grimmory;

  # Workaround for <https://github.com/grimmory-tools/grimmory/issues/2407>.
  #
  # Grimmory v3.3.2 added SSRF hardening (`app.outbound.restricted-ranges`,
  # enforced through Spring Boot's InetAddressFilter). The filtered HTTP client
  # is annotated `@Primary`, so it also gets injected into OidcTokenClient in
  # place of the unfiltered `oidcRestTemplate` bean that was meant for it, and
  # the OIDC token exchange dies with
  #   FilteredHostException: Filtered host 'auth.daftdaf.dev'
  # because our Authelia resolves to a LAN address from inside the container.
  # (OIDC discovery builds its own client, which is why "Test Connection"
  # passes while login fails.)
  #
  # Upstream's default list, minus the three RFC 1918 ranges. Loopback, link
  # local (cloud metadata) and the reserved/documentation blocks stay blocked.
  # Drop this once #2407 is fixed upstream.
  outboundRestrictedRanges = [
    "0.0.0.0/8"
    "100::/64"
    "100.64.0.0/10"
    "::1/128"
    "127.0.0.0/8"
    "::/128"
    "169.254.0.0/16"
    "192.0.0.0/24"
    "192.0.0.0/29"
    "192.0.2.0/24"
    "192.88.99.0/24"
    "198.18.0.0/15"
    "198.51.100.0/24"
    "2001:10::/28"
    "2001::/23"
    "2001:0200::/48"
    "2001::/32"
    "2001:db8::/32"
    "2002::/16"
    "203.0.113.0/24"
    "240.0.0.0/4"
    "255.255.255.255/32"
    "64:ff9b:1::/48"
    "64:ff9b::/96"
    "fc00::/7"
    "fe80::/10"
  ];
in
{
  options.${namespace}.services.grimmory = {
    enable = mkEnableOption "Whether or not to configure grimmory.";
    subDomain = mkOpt types.str "grimmory" "The subdomain for the service.";
  };

  config = mkIf cfg.enable {
    sops.secrets = {
      "grimmory/db-user-password".sopsFile = lib.snowfall.fs.get-file "secrets/daf/grimmory.yaml";
      "grimmory/db-root-password".sopsFile = lib.snowfall.fs.get-file "secrets/daf/grimmory.yaml";
    };

    nps.stacks = {
      grimmory = {
        enable = true;

        containers.grimmory = {
          expose = true;
          traefik.subDomain = cfg.subDomain;

          volumes = lib.mkForce [
            "/mnt/grimmory/livres:/livres"
            "/mnt/grimmory/books:/books"
            "/mnt/audio/Audiobooks:/audiobooks"
            "${config.nps.storageBaseDir}/grimmory/bookdrop:/bookdrop"
            "${config.nps.storageBaseDir}/grimmory/data:/app/data"
          ];
          # image = lib.mkForce "ghcr.io/grimmory-app/grimmory:develop-0136060d";

          extraEnv.APP_OUTBOUND_RESTRICTED_RANGES = lib.concatStringsSep "," outboundRestrictedRanges;
        };

        oidc.registerClient = true;

        db = {
          userPasswordFile = config.sops.secrets."grimmory/db-user-password".path;
          rootPasswordFile = config.sops.secrets."grimmory/db-root-password".path;
        };
      };
    };
  };
}
