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
    base-url = mkOpt types.str "http://localhost:3000" "The base url";
    meilisearch-key = mkOpt types.str "" "The meilisearch key";
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers."bar-assistant" = {
      image = "barassistant/server:v4";
      environment = {
        "ALLOW_REGISTRATION" = "true";
        "APP_URL" = "${cfg.base-url}/bar";
        "CACHE_DRIVER" = "redis";
        "MEILISEARCH_HOST" = "http://meilisearch:7700";
        "MEILISEARCH_KEY" = cfg.meilisearch-key;
        "REDIS_HOST" = "redis";
        "SESSION_DRIVER" = "redis";
      };
      volumes = [
        "bar-assistant_bar_data:/var/www/cocktails/storage/bar-assistant:rw"
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
    systemd.services."podman-bar-assistant" = {
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
    virtualisation.oci-containers.containers."bar-assistant-meilisearch" = {
      image = "getmeili/meilisearch:v1.9";
      environment = {
        "MEILI_ENV" = "production";
        "MEILI_MASTER_KEY" = cfg.meilisearch-key;
      };
      volumes = [
        "bar-assistant_meilisearch_data:/meili_data:rw"
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
    virtualisation.oci-containers.containers."bar-assistant-salt-rim" = {
      image = "barassistant/salt-rim:v3";
      environment = {
        "API_URL" = "${cfg.base-url}/bar";
        "MEILISEARCH_URL" = "${cfg.base-url}/search";
      };
      dependsOn = [
        "bar-assistant"
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
    virtualisation.oci-containers.containers."bar-assistant-webserver" = {
      image = "nginx:alpine";
      volumes = [
        "/tmp/docker/nginx.conf:/etc/nginx/conf.d/default.conf:rw"
      ];
      ports = [
        "3000:3000/tcp"
      ];
      dependsOn = [
        "bar-assistant"
        "bar-assistant-meilisearch"
        "bar-assistant-salt-rim"
      ];
      log-driver = "journald";
      extraOptions = [
        "--network-alias=webserver"
        "--network=bar-assistant_default"
      ];
    };
    systemd.services."podman-bar-assistant-webserver" = {
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
