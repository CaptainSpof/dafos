{
  lib,
  config,
  namespace,
  pkgs,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) enabled disabled;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.services.streaming;

  brandingXml = pkgs.writeText "branding.xml" ''
    <?xml version="1.0" encoding="utf-8"?>
    <BrandingOptions xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
      <LoginDisclaimer>&lt;form action="${config.nps.containers.jellyfin.traefik.serviceUrl}/sso/OID/start/authelia"&gt;
        &lt;button class="raised block emby-button button-submit"&gt;
        Se connecter avec Authelia
        &lt;/button&gt;
        &lt;/form&gt;
      </LoginDisclaimer>
      <CustomCss>
      @import url("https://cdn.jsdelivr.net/gh/lscambo13/ElegantFin@main/Theme/ElegantFin-jellyfin-theme-build-latest-minified.css"); 
      a.raised.emby-button {
        padding: 0.9em 1em;
        color: inherit !important;
      }
      .disclaimerContainer {
        display: block;
      }
      </CustomCss>
      <SplashscreenEnabled>true</SplashscreenEnabled>
    </BrandingOptions>
  '';
in
  {

    options.${namespace}.services.streaming = {
      enable = mkEnableOption "Whether or not to configure streaming.";
      base-url = mkOpt types.str "streaming.daftdaf.dev" "The base url";
    };

    config = mkIf cfg.enable {
      sops.secrets = {
          "qui/authelia/client-secret".sopsFile = lib.snowfall.fs.get-file "secrets/daf/streaming.yaml";
          "jellyfin/authelia/client-secret".sopsFile = lib.snowfall.fs.get-file "secrets/daf/streaming.yaml";
          "gluetun/wg-pk".sopsFile = lib.snowfall.fs.get-file "secrets/daf/streaming.yaml";
          "gluetun/wg-address".sopsFile = lib.snowfall.fs.get-file "secrets/daf/streaming.yaml";
      };

      nps = {
        externalStorageBaseDir = "/mnt/yahrr";
        stacks = {
          streaming = {
            enable = true;

            containers = {
              gluetun = {
                ports = ["8888:8888"];
              };
              jellyfin = {
                expose = true;
	            volumes = lib.mkForce [ 
	              "/mnt/videos/Movies:/movies"
	              "/mnt/videos/Shows:/shows"
                  "${config.nps.storageBaseDir}/streaming/jellyfin:/config"
                  "${brandingXml}:/config/branding.xml"
	            ];
              };
              qui.expose = true;
              qbittorrent = {
	            volumes = lib.mkForce [ 
	              "/mnt/yahrr:/yahrr"
                  "${config.nps.storageBaseDir}/streaming/radarr:/config"
	            ];
              };
              sonarr = {
	            volumes = lib.mkForce [ 
	              "/mnt/videos/Shows:/media"
	              "/mnt/yahrr:/yahrr"
                  "${config.nps.storageBaseDir}/streaming/sonarr:/config"
	            ];
              };
              radarr = {
	            volumes = lib.mkForce [ 
	              "/mnt/videos/Movies:/media"
	              "/mnt/yahrr:/yahrr"
                  "${config.nps.storageBaseDir}/streaming/radarr:/config"
	            ];
              };
            };

            jellyfin = {
              enable = true;

              oidc = {
                enable = true;
                clientSecretFile = config.sops.secrets."jellyfin/authelia/client-secret".path;
              };
            };
            gluetun = {
              enable = true;

              vpnProvider = "protonvpn";
              wireguardPrivateKeyFile = config.sops.secrets."gluetun/wg-pk".path;
              wireguardPresharedKeyFile = pkgs.writeText "wg-psk-empty" "";
              wireguardAddressesFile = config.sops.secrets."gluetun/wg-address".path;
            };
            qbittorrent = enabled;
            qui = {
              enable = true;

              oidc = {
                enable = true;
                clientSecretFile = config.sops.secrets."qui/authelia/client-secret".path;
              };
            };
            bazarr = enabled;
            prowlarr = enabled;
            profilarr = enabled;
            radarr = enabled;
            seerr = enabled;
            sonarr = enabled;
          };
        };
      };
    };
  }
