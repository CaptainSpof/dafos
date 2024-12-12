{
  description = "Here lies my shipwrecks. I mean fleet of hosts.";

  inputs = {
    # NixPkgs (nixos-24.05)
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.05";

    # NixPkgs (nixos-unstable)
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # NixPkgs Master
    nixpkgs-master.url = "github:nixos/nixpkgs/master";

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nix User Repository (master)
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Flake Compat
    flake-compat = {
      url = "github:nix-community/flake-compat";
      flake = false;
    };

    # Flake Utils
    flake-utils.url = "github:numtide/flake-utils";

    # Hardware Configuration
    nixos-hardware.url = "github:nixos/nixos-hardware";

    # Generate System Images
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Snowfall Lib
    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Snowfall Flake
    snowfall-flake = {
      url = "github:snowfallorg/flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Weekly updating nix-index database
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Comma
    comma = {
      url = "github:nix-community/comma";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nuenv
    nuenv.url = "github:DeterminateSystems/nuenv";

    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Plasma-Manager
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };

    kwin-effects-forceblur = {
      url = "github:taj-ny/kwin-effects-forceblur";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        utils.follows = "flake-utils";
      };
    };

    lightly.url = "github:Bali10050/Lightly";

    # Pre Commit Hooks
    pre-commit-hooks-nix.url = "github:cachix/git-hooks.nix";

    # System Deployment
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Disko
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Vault Integration
    vault-service = {
      url = "github:DeterminateSystems/nixos-vault-service";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    let
      lib = inputs.snowfall-lib.mkLib {
        inherit inputs;
        src = ./.;

        snowfall = {
          namespace = "dafos";

          meta = {
            name = "dafos";
            title = "It ain't pretty, but it's mine.";
          };
        };
      };
    in
    lib.mkFlake {
      channels-config = {
        allowUnfree = true;
        permittedInsecurePackages = [
          "aspnetcore-runtime-6.0.36"
          "aspnetcore-runtime-wrapped-6.0.36"
          "dotnet-sdk-wrapped-6.0.428"
          "dotnet-sdk-6.0.428"
        ];
      };

      overlays = with inputs; [
        emacs-overlay.overlays.default
        nuenv.overlays.default
        nur.overlays.default
        snowfall-flake.overlays.default
      ];

      homes.modules = with inputs; [
        nix-index-database.hmModules.nix-index
        plasma-manager.homeManagerModules.plasma-manager
        # nur.modules.homeManager.default
      ];

      systems.modules.nixos = with inputs; [
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        vault-service.nixosModules.nixos-vault-service
      ];

      deploy = lib.mkDeploy { inherit (inputs) self; };

      checks = builtins.mapAttrs (
        _system: deploy-lib: deploy-lib.deployChecks inputs.self.deploy
      ) inputs.deploy-rs.lib;
    };
}
