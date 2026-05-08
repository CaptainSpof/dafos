{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib) mkIf getExe';
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.apps.qbittorrent;
  username = config.${namespace}.user.name;
in
  {
    options.${namespace}.apps.qbittorrent = {
      enable = mkBoolOpt false "Whether or not to enable qbittorent.";
      nox.enable = mkBoolOpt false "Whether or not to enable qbittorent-nox.";
    };

    config = mkIf cfg.enable {

      users.groups.yahrr.members = [ "qbittorent" ];
      services.qbittorrent = {
        enable = true;
        group = "yahrr";
        openFirewall = true;
        webuiPort = 8080;
        serverConfig = {
          BitTorrent = {
            Session.Interface = "tun0";
            Session.InterfaceName = "tun0";
            Session.DefaultSavePath = "/mnt/yahrr";
            Session.TempPath = "/mnt/yahrr/dl";
            Session.TempPathEnabled = "true";
          };
          Preferences = {
            WebUI = {
              AlternativeUIEnabled = false;
              RootFolder = "${pkgs.vuetorrent}/share/vuetorrent";
              Username = "daf";
              Password_PBKDF2 = "@ByteArray(DJoGQGu07fwDz/WfoGIBew==:QbhpSH+h5mNMA9LTRtVW2LNqXuMNviMzD3IYNoi1lEQ4iNUl/MjHXIYJaYafMxvTpEEB7mVqgmqCZZP0fDEG+w==)";
            };
          };
        };
        extraArgs = [
          "--confirm-legal-notice"
        ];
      };

      services.caddy.virtualHosts = {
        "torrent.daftdaf.dev".extraConfig = ''
          reverse_proxy http://0.0.0.0:8080
          import cloudflare
        '';
      };

      environment.systemPackages = with pkgs; [ qbittorrent ];
    };
  }
