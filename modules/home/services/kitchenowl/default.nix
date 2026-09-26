{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) mkOpt mkBoolOpt;

  cfg = config.${namespace}.services.kitchenowl;
in
{

  options.${namespace}.services.kitchenowl = {
    enable = mkEnableOption "Whether or not to configure kitchenowl.";
    subDomain = mkOpt types.str "course" "The subdomain of the web frontend.";
    # The shopping list is used from the shop, through the mobile app.
    expose = mkBoolOpt true "Whether to reach the instance from outside the LAN/tailnet.";
  };

  config = mkIf cfg.enable {
    sops.secrets = {
      "kitchenowl/jwt-secret" = {
        sopsFile = lib.snowfall.fs.get-file "secrets/daf/kitchenowl.yaml";
      };
      "kitchenowl/authelia/client-secret" = {
        sopsFile = lib.snowfall.fs.get-file "secrets/daf/kitchenowl.yaml";
      };
    };

    nps.stacks.kitchenowl = {
      enable = true;

      jwtSecretFile = config.sops.secrets."kitchenowl/jwt-secret".path;

      oidc = {
        enable = true;
        clientSecretFile = config.sops.secrets."kitchenowl/authelia/client-secret".path;
      };

      # The OIDC redirect URI is derived from the web container's URL, so the
      # subdomain has to be set here rather than through an alias.
      containers.kitchenowl-web = {
        inherit (cfg) expose;
        traefik.subDomain = cfg.subDomain;
        # Upstream's displayName is misspelt "KitchwenOwl".
        dashboard.name = lib.mkForce "KitchenOwl";
      };
      containers.kitchenowl-backend.dashboard.name = lib.mkForce "KitchenOwl";
    };
  };
}
