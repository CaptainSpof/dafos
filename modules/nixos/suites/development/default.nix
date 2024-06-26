{ config, lib, pkgs, namespace, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.suites.development;
in
{
  options.${namespace}.suites.development = with types; {
    enable = mkBoolOpt false "Whether or not to enable common development configuration.";
    docker.enable = mkBoolOpt false "Whether or not to enable podman development configuration.";
    keyboard.enable = mkBoolOpt false "Whether or not to enable keyboard development configuration.";
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [
      12345
      3000
      3001
      8080
      8081
    ];

    dafos = {
      programs.terminal = {
        tools = {
          qmk.enable = cfg.keyboard.enable;
        };
      };

      virtualisation = {
        podman.enable = cfg.docker.enable;
      };
    };
  };
}
