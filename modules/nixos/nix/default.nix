{
  config,
  pkgs,
  lib,
  namespace,
  inputs,
  ...
}:

let
  inherit (lib)
    mkIf
    types
    optional
    mapAttrsToList
    ;
  inherit (lib.${namespace}) mkOpt mkBoolOpt;
  cfg = config.${namespace}.nix;
  substituters-submodule = types.submodule (_: {
    options = with types; {
      key = mkOpt (nullOr str) null "The trusted public key for this substituter.";
    };
  });
in
{
  options.${namespace}.nix = with types; {
    enable = mkBoolOpt true "Whether or not to manage nix configuration.";
    nh.enable = mkBoolOpt false "Whether or not to enable nh.";
    package = mkOpt package pkgs.nixVersions.latest "Which nix package to use.";

    default-substituter = {
      url = mkOpt str "https://cache.nixos.org" "The url for the substituter.";
      key =
        mkOpt str "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "The trusted public key for the substituter.";
    };

    extra-substituters = mkOpt (attrsOf substituters-submodule) {
      "https://nix-community.cachix.org" = {
        key = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
      };
      "https://nix-gaming.cachix.org" = {
        key = "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4=";
      };
      "https://niri.cachix.org" = {
        key = "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964=";
      };
      "https://vicinae.cachix.org" = {
        key = "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc=";
      };
    } "Extra substituters to configure.";
  };

  config = mkIf cfg.enable {
    assertions = mapAttrsToList (name: value: {
      assertion = value.key != null;
      message = "dafos.nix.extra-substituters.${name}.key must be set";
    }) cfg.extra-substituters;

    environment.systemPackages = with pkgs; [
      deploy-rs
      nix-index
      nix-init
      nix-prefetch-git
      nix-output-monitor
      flake-checker
      yaml2nix
    ];

    programs.nh = mkIf cfg.nh.enable {
      enable = true;
      clean = {
        enable = true;
        extraArgs = "--keep 15 --keep-since 14d";
      };
    };

    nix =
      let
        users = [
          "root"
          config.${namespace}.user.name
        ]
        ++ optional config.services.hydra.enable "hydra";
      in
      {
        inherit (cfg) package;

        settings = {
          experimental-features = "nix-command flakes pipe-operators";
          http-connections = 50;
          warn-dirty = false;
          log-lines = 50;
          sandbox = "relaxed";
          auto-optimise-store = true;
          trusted-users = users;
          allowed-users = users;

          substituters = [
            cfg.default-substituter.url
          ]
          ++ (mapAttrsToList (name: _value: name) cfg.extra-substituters);
          trusted-public-keys = [
            cfg.default-substituter.key
          ]
          ++ (mapAttrsToList (_name: value: value.key) cfg.extra-substituters);
        };

        gc = mkIf (!cfg.nh.enable) {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 30d";
        };

        # flake-utils-plus
        generateRegistryFromInputs = true;
        generateNixPathFromInputs = true;
        linkInputs = true;
      };
  };
}
