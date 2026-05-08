{
  lib,
  config,
  namespace,
  pkgs,
  ...
}:

let
  cfg = config.${namespace}.services.caddy;

  inherit (lib) mkEnableOption mkIf;
in
  {
    options.${namespace}.services.caddy = {
      enable = mkEnableOption "Whether or not to configure caddy.";
    };

    config = mkIf cfg.enable {

      sops.secrets."cloudflare-api-token-env" = {
        sopsFile = lib.snowfall.fs.get-file "secrets/daf/cloudflare.yaml";
        owner = "caddy";
      };

      services.caddy = {
        enable = true;

        package = pkgs.caddy.withPlugins {
          plugins = [
            "github.com/caddy-dns/cloudflare@v0.2.1"
          ];
          hash = "sha256-Zls+5kWd/JSQsmZC4SRQ/WS+pUcRolNaaI7UQoPzJA0=";
        };
        extraConfig = ''
          (cloudflare) {
          tls {
            dns cloudflare {env.CLOUDFLARE_API_TOKEN}
            resolvers 1.1.1.1 8.8.8.8
          }
        }
        (headers) {
          header {
            # Enable HSTS
            Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
            # Prevent MIME sniffing
            X-Content-Type-Options "nosniff"
            # Frame options
            X-Frame-Options "SAMEORIGIN"
            # XSS protection
            X-XSS-Protection "1; mode=block"
            # Referrer policy
            Referrer-Policy "strict-origin-when-cross-origin"
          }
        }
        '';

        virtualHosts = {
          "daftdaf.dev".extraConfig = ''
            respond "Hello, world!"
          import cloudflare
          '';
          "auth.daftdaf.dev".extraConfig = ''
            reverse_proxy http://127.0.0.1:10080 {
              header_up X-Forwarded-Proto https
              header_up Host {host}
            }
            import cloudflare
          '';
          "grimmory.daftdaf.dev".extraConfig = ''
            # reverse_proxy http://127.0.0.1:10080
            reverse_proxy localhost:6060

            import cloudflare
          '';
          "bar.daftdaf.dev".extraConfig = ''
            reverse_proxy http://0.0.0.0:7000
            import cloudflare

            handle_path /api/* {
              reverse_proxy http://0.0.0.0:7002
            }
            handle_path /search/* {
              reverse_proxy http://0.0.0.0:7001
            }
          '';
          "calibre-server.daftdaf.dev".extraConfig = ''
            reverse_proxy http://0.0.0.0:8585
            import cloudflare
          '';
          "fp.daftdaf.dev".extraConfig = ''
            reverse_proxy http://0.0.0.0:8181
            import cloudflare
          '';

          # Home-Assistant
          "hass.daftdaf.dev".extraConfig = ''
            reverse_proxy http://0.0.0.0:8123
            import cloudflare
          '';
          "home.daftdaf.dev".extraConfig = ''
            reverse_proxy http://0.0.0.0:8123
            import cloudflare
          '';

          "miam.daftdaf.dev".extraConfig = ''
            import cloudflare
            import headers

            reverse_proxy 0.0.0.0:9000
          '';
          "donetick.daftdaf.dev".extraConfig = ''
            reverse_proxy http://127.0.0.1:10080

            import cloudflare
            import headers
          '';
          "papra.daftdaf.dev".extraConfig = ''
            reverse_proxy http://127.0.0.1:10080
            import cloudflare
          '';
          "shelfmark.daftdaf.dev".extraConfig = ''
            reverse_proxy http://127.0.0.1:10080
            import cloudflare
          '';
          "pdf.daftdaf.dev".extraConfig = ''
            reverse_proxy http://0.0.0.0:8001
            import cloudflare
          '';
          "frame.daftdaf.dev".extraConfig = ''
            reverse_proxy http://0.0.0.0:8084
            import cloudflare
          '';
          "z2m.daftdaf.dev".extraConfig = ''
            reverse_proxy http://0.0.0.0:8090
            import cloudflare
          '';
          "torrent.daftdaf.dev".extraConfig = ''
            reverse_proxy http://0.0.0.0:8080
            import cloudflare
          '';
        };
      };

      systemd.services.caddy = {
        serviceConfig = {
          EnvironmentFile = config.sops.secrets."cloudflare-api-token-env".path;
          TimeoutStartSec = "5m";
        };
      };
    };
  }
