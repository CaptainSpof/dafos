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
    sonora.enable = mkBoolOpt false "Whether or not to enable the Sonora music streaming client.";
  };

  config = mkIf cfg.enable {
    home.packages =
      with pkgs;
      [
        # nixpkgs' reuse (amberol build tool) drops its man output with
        # structured attrs on.
        (amberol.override { reuse = reuse.overrideAttrs { __structuredAttrs = false; }; })
      ]
      ++ lib.optionals cfg.mixing.enable [
        ardour
      ]
      ++ lib.optionals cfg.sonora.enable [
        inputs.sonora.packages.${pkgs.stdenv.hostPlatform.system}.sonora
      ];
  };
}
