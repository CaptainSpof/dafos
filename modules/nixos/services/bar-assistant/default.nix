{
  lib,
  config,
  namespace,
  pkgs,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.services.bar-assistant;
in
{

  options.${namespace}.services.bar-assistant = {
    enable = mkEnableOption "Whether or not to configure bar-assistant.";
    base-url = mkOpt types.str "https://bar.daftdaf.dev" "The base url";
  };

  config = mkIf cfg.enable {
    sops.secrets."meilisearch-key-env".sopsFile =
      lib.snowfall.fs.get-file "secrets/daf/bar-assistant.yaml";
    sops.secrets."meilisearch-master-key-env".sopsFile =
      lib.snowfall.fs.get-file "secrets/daf/bar-assistant.yaml";

    # Meilisearch
    virtualisation.oci-containers.containers."bar-assistant-meilisearch" = {
      image = "getmeili/meilisearch:v1.15";

      environmentFiles = [ config.sops.secrets."meilisearch-master-key-env".path ];
      environment = {
        "MEILI_ENV" = "production";
        "MEILI_NO_ANALYTICS" = "true";
      };
      volumes = [
        "bar-assistant_meilisearch_data:/meili_data:rw"
      ];
      ports = [
        "7001:7700/tcp"
      ];
      log-driver = "journald";
      extraOptions = [
        "--network-alias=meilisearch"
        "--network=bar-assistant_default"
      ];
    };

    systemd.services."podman-bar-assistant-meilisearch" = {
      serviceConfig = {
        Restart = lib.mkOverride 90 "always";
      };
      after = [
        "podman-network-bar-assistant_default.service"
        "podman-volume-bar-assistant_meilisearch_data.service"
      ];
      requires = [
        "podman-network-bar-assistant_default.service"
        "podman-volume-bar-assistant_meilisearch_data.service"
      ];
      partOf = [
        "podman-compose-bar-assistant-root.target"
      ];
      wantedBy = [
        "podman-compose-bar-assistant-root.target"
      ];
    };

    # Redis
    virtualisation.oci-containers.containers."bar-assistant-redis" = {
      image = "redis";
      environment = {
        "ALLOW_EMPTY_PASSWORD" = "yes";
      };
      log-driver = "journald";
      extraOptions = [
        "--network-alias=redis"
        "--network=bar-assistant_default"
      ];
    };

    systemd.services."podman-bar-assistant-redis" = {
      serviceConfig = {
        Restart = lib.mkOverride 90 "always";
      };
      after = [
        "podman-network-bar-assistant_default.service"
      ];
      requires = [
        "podman-network-bar-assistant_default.service"
      ];
      partOf = [
        "podman-compose-bar-assistant-root.target"
      ];
      wantedBy = [
        "podman-compose-bar-assistant-root.target"
      ];
    };

    # Bar-Assistant Server
    virtualisation.oci-containers.containers."bar-assistant-bar-assistant" = {
      image = "barassistant/server:v5";
      environmentFiles = [ config.sops.secrets."meilisearch-key-env".path ];
      environment = {
        "ALLOW_REGISTRATION" = "true";
        "APP_URL" = "${cfg.base-url}/api";
        "BASE_URL" = cfg.base-url;
        "CACHE_DRIVER" = "redis";
        "MEILISEARCH_HOST" = "http://meilisearch:7700";
        "REDIS_HOST" = "redis";
        "SESSION_DRIVER" = "redis";
      };
      volumes = [
        "bar-assistant_bar_data:/var/www/cocktails/storage/bar-assistant:rw"
      ];
      ports = [
        "7002:8080/tcp"
      ];
      dependsOn = [
        "bar-assistant-meilisearch"
        "bar-assistant-redis"
      ];
      log-driver = "journald";
      extraOptions = [
        "--network-alias=bar-assistant"
        "--network=bar-assistant_default"
      ];
    };

    systemd.services."podman-bar-assistant-bar-assistant" = {
      serviceConfig = {
        Restart = lib.mkOverride 90 "always";
      };
      after = [
        "podman-network-bar-assistant_default.service"
        "podman-volume-bar-assistant_bar_data.service"
      ];
      requires = [
        "podman-network-bar-assistant_default.service"
        "podman-volume-bar-assistant_bar_data.service"
      ];
      partOf = [
        "podman-compose-bar-assistant-root.target"
      ];
      wantedBy = [
        "podman-compose-bar-assistant-root.target"
      ];
    };

    # Salt-Rim
    virtualisation.oci-containers.containers."bar-assistant-salt-rim" = {
      image = "barassistant/salt-rim:v4";
      environment = {
        "API_URL" = "${cfg.base-url}/api";
        "MEILISEARCH_URL" = "${cfg.base-url}/search";
        "BASE_URL" = cfg.base-url;
      };
      ports = [
        "7000:8080/tcp"
      ];
      dependsOn = [
        "bar-assistant-bar-assistant"
      ];
      log-driver = "journald";
      extraOptions = [
        "--network-alias=salt-rim"
        "--network=bar-assistant_default"
      ];
    };

    systemd.services."podman-bar-assistant-salt-rim" = {
      serviceConfig = {
        Restart = lib.mkOverride 90 "always";
      };
      after = [
        "podman-network-bar-assistant_default.service"
      ];
      requires = [
        "podman-network-bar-assistant_default.service"
      ];
      partOf = [
        "podman-compose-bar-assistant-root.target"
      ];
      wantedBy = [
        "podman-compose-bar-assistant-root.target"
      ];
    };

    # Networks
    systemd.services."podman-network-bar-assistant_default" = {
      path = [ pkgs.podman ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStop = "podman network rm -f bar-assistant_default";
      };
      script = ''
      podman network inspect bar-assistant_default || podman network create bar-assistant_default
    '';
      partOf = [ "podman-compose-bar-assistant-root.target" ];
      wantedBy = [ "podman-compose-bar-assistant-root.target" ];
    };

    # Volumes
    systemd.services."podman-volume-bar-assistant_bar_data" = {
      path = [ pkgs.podman ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
      podman volume inspect bar-assistant_bar_data || podman volume create bar-assistant_bar_data
    '';
      partOf = [ "podman-compose-bar-assistant-root.target" ];
      wantedBy = [ "podman-compose-bar-assistant-root.target" ];
    };

    systemd.services."podman-volume-bar-assistant_meilisearch_data" = {
      path = [ pkgs.podman ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
      podman volume inspect bar-assistant_meilisearch_data || podman volume create bar-assistant_meilisearch_data
    '';
      partOf = [ "podman-compose-bar-assistant-root.target" ];
      wantedBy = [ "podman-compose-bar-assistant-root.target" ];
    };

    # Root service
    # When started, this will automatically create all resources and start
    # the containers. When stopped, this will teardown all resources.
    systemd.targets."podman-compose-bar-assistant-root" = {
      unitConfig = {
        Description = "Root target generated by compose2nix.";
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}
