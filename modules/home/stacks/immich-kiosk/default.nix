# nps-style stack module for immich-kiosk, following the conventions of the
# stacks shipped by nix-podman-stacks (see e.g. its glance/it-tools modules).
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  name = "immich-kiosk";
  cfg = config.nps.stacks.${name};

  yaml = pkgs.formats.yaml { };

  category = "Media & Downloads";
  displayName = "Immich Kiosk";
  description = "Immich Photo Frame";
in
{
  imports = import "${inputs.nix-podman-stacks}/modules/mkAliases.nix" config lib name [ name ];

  options.nps.stacks.${name} = {
    enable = lib.mkEnableOption name;

    immichUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://host.containers.internal:2283";
      description = "URL the kiosk uses to reach the Immich server.";
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = ''
        Env-formatted files providing `KIOSK_*` variables (e.g.
        `KIOSK_IMMICH_API_KEY`, `KIOSK_ALBUMS`). Use for secrets that must not
        end up in the nix store.
      '';
    };

    weatherApiKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "File containing a raw OpenWeatherMap API key.";
    };

    settings = lib.mkOption {
      inherit (yaml) type;
      default = { };
      apply = settings: yaml.generate "config.yaml" settings;
      description = ''
        Settings written to the kiosk's `config.yaml`.
        Environment variables (`KIOSK_*`) take precedence over these.

        See <https://github.com/damongolding/immich-kiosk#configuration-options>
      '';
    };

    customCss = lib.mkOption {
      type = lib.types.lines;
      default = "";
      apply = pkgs.writeText "custom.css";
      description = "Custom CSS, mounted at `/custom.css` inside the container.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.podman.containers.${name} = {
      # renovate: versioning=semver
      # 0.40.0+ is required for Immich v3 (older versions expect assets
      # embedded in the album response and log "no assets found").
      image = "ghcr.io/damongolding/immich-kiosk:0.43.1";

      port = 3000;

      traefik = {
        inherit name;
        subDomain = lib.mkDefault "kiosk";
      };

      environment.KIOSK_IMMICH_URL = cfg.immichUrl;
      environmentFile = cfg.environmentFiles;

      fileEnvMount = lib.optionalAttrs (cfg.weatherApiKeyFile != null) {
        KIOSK_WEATHER_API_KEY_FILE = toString cfg.weatherApiKeyFile;
      };

      # The image runs as distroless `nonroot` (uid 65532); map the host user
      # onto it so the mounted 0400 secret file stays readable in-container.
      extraConfig.Container.UserNS = "keep-id:uid=65532,gid=65532";

      volumeMap = {
        settings = "${cfg.settings}:/config/config.yaml";
        customCss = "${cfg.customCss}:/custom.css";
      };

      homepage = {
        inherit category;
        name = displayName;
        settings = {
          inherit description;
          icon = "immich";
        };
      };
      glance = {
        inherit category description;
        name = displayName;
        id = name;
        icon = "di:immich";
      };
    };
  };
}
