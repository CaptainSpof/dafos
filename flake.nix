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

    socle = {
      url = "github:dvdjv/socle";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Comma
    comma = {
      url = "github:nix-community/comma";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-gaming = {
      url = "github:fufexan/nix-gaming";
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

    # Sops (Secrets)
    sops-nix = {
      url = "github:Mic92/sops-nix";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
    };

    kwin-effects-forceblur = {
      url = "github:taj-ny/kwin-effects-forceblur";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        utils.follows = "flake-utils";
      };
    };

    firefox = {
      url = "github:nix-community/flake-firefox-nightly";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        cachix.follows = "nixpkgs";
      };
    };

    hass-tapo-control = {
      url = "github:JurajNyiri/homeAssistant-Tapo-Control";
      flake = false;
    };

    darkly = {
      url = "github:Bali10050/Darkly";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Git Hooks
    git-hooks-nix.url = "github:cachix/git-hooks.nix";

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

    yaml2nix.url = "github:euank/yaml2nix";
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
          "emacs-unstable-pgtk-30.1"
          "emacs-unstable-pgtk-with-packages-30.1"
          "dotnet-sdk-6.0.428"
          "olm-3.2.16"
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
        sops-nix.homeManagerModules.sops
      ];

      systems.modules.nixos = with inputs; [
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        nix-gaming.nixosModules.platformOptimizations
        sops-nix.nixosModules.sops
        vault-service.nixosModules.nixos-vault-service
      ];

      templates = {
        rust.description = "Rust template";
      };

      deploy = lib.mkDeploy { inherit (inputs) self; };

      outputs-builder = channels: {
        formatter = inputs.treefmt-nix.lib.mkWrapper channels.nixpkgs ./treefmt.nix;
      };
    };
}
