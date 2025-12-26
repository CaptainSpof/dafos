{
  description = "Here lies my shipwrecks. I mean fleet of hosts.";

  inputs = {
    # NixPkgs (nixos-25.05)
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";

    # NixPkgs (nixos-unstable)
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    # nixpkgs.url = "github:K900/nixpkgs/plasma-6.4";

    # NixPkgs Master
    nixpkgs-master.url = "github:nixos/nixpkgs";

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

    nix-firefox-addons.url = "github:osipog/nix-firefox-addons";

    nix-podman-stacks = {
      url = "github:Tarow/nix-podman-stacks";
      inputs.nixpkgs.follows = "nixpkgs";
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

    # Weekly updating nix-index database
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri.url = "github:sodiboo/niri-flake";

    niri-switch = {
      url = "github:Kiki-Bouba-Team/niri-switch";
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
      inputs.nixpkgs.follows = "nixpkgs";
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
    git-hooks-nix.inputs.nixpkgs.follows = "nixpkgs";

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

    dgop = {
      url = "github:AvengeMedia/dgop";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dank-material-shell = {
      url = "github:AvengeMedia/DankMaterialShell";
      # url = "git+file:///home/daf/Repositories/DankMaterialShell";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.dgop.follows = "dgop";
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vicinae.url = "github:vicinaehq/vicinae";
    vicinae-extensions.url = "github:vicinaehq/extensions";

    # Vault Integration
    vault-service = {
      url = "github:DeterminateSystems/nixos-vault-service";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
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
        # permittedInsecurePackages = [
          # "aspnetcore-runtime-6.0.36"
          # "emacs-unstable-pgtk-30.1"
          # "emacs-unstable-pgtk-with-packages-30.1"
          # "dotnet-sdk-6.0.428"
          # "qtwebengine-5.15.19"
          # "olm-3.2.16"
        # ];
      };

      overlays = with inputs; [
        emacs-overlay.overlays.default
        niri.overlays.niri
        nuenv.overlays.default
        nur.overlays.default
        nix-firefox-addons.overlays.default
      ];

      homes.modules = with inputs; [
        nix-podman-stacks.homeModules.nps
        nix-index-database.homeModules.nix-index
        noctalia.homeModules.default
        plasma-manager.homeModules.plasma-manager
        sops-nix.homeManagerModules.sops
        zen-browser.homeModules.beta
        niri.homeModules.niri
        vicinae.homeManagerModules.default
        dank-material-shell.homeModules.dank-material-shell
        dank-material-shell.homeModules.niri
      ];

      systems.modules.nixos = with inputs; [
        disko.nixosModules.disko
        noctalia.nixosModules.default
        home-manager.nixosModules.home-manager
        nix-gaming.nixosModules.platformOptimizations
        sops-nix.nixosModules.sops
        vault-service.nixosModules.nixos-vault-service
      ];

      deploy = lib.mkDeploy { inherit (inputs) self; };

      outputs-builder = channels: {
        formatter = inputs.treefmt-nix.lib.mkWrapper channels.nixpkgs ./treefmt.nix;
      };
    };
}
