{
  pkgs,
  config,
  lib,
  namespace,
  inputs,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.suites.music;
in
{
  options.${namespace}.suites.music = {
    enable = mkBoolOpt false "Whether or not to enable music configuration.";
    mixing.enable = mkBoolOpt false "Whether or not to enable music mixing configuration.";
    sonora.enable = mkBoolOpt true "Whether or not to enable the Sonora music streaming client.";
  };

  config = mkIf cfg.enable {
    home.packages =
      with pkgs;
      [
        amberol
      ]
      ++ lib.optionals cfg.mixing.enable [
        ardour
      ]
      ++ lib.optionals cfg.sonora.enable [
        inputs.sonora.packages.${pkgs.stdenv.hostPlatform.system}.sonora
      ];
  };
}
