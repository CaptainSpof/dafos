{
  description = "Here lies my shipwrecks. I mean fleet of hosts.";

  inputs = {
    # NixPkgs (nixos-25.05)
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";

    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    # nixpkgs.url = "github:K900/nixpkgs/plasma-6.4";

    # NixPkgs Master
    nixpkgs-master.url = "github:nixos/nixpkgs";

    # NixPkgs Staging
    nixpkgs-staging.url = "github:nixos/nixpkgs/staging";

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

    nix-firefox-addons = {
      url = "github:osipog/nix-firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-desktop.url = "github:aaddrick/claude-desktop-debian";

    nix-podman-stacks = {
      url = "github:Tarow/nix-podman-stacks";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
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

    # Pinned to 350668e (not tracking main): the very next commit, 7007897
    # ("Update flake.lock", 2026-07-01), shipped with an empty refs.nix, which
    # is a nix file and breaks eval ("syntax error, unexpected end of file").
    # 350668e is the last known-good commit (2026-06-30). Unpin back to
    # `github:epireyn/niri-flake` once upstream fixes it.
    niri.url = "github:epireyn/niri-flake/350668e";

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
    nuenv = {
      url = "github:DeterminateSystems/nuenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    kwin-effects-better-blur-dx = {
      url = "github:xarblu/kwin-effects-better-blur-dx";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    firefox = {
      url = "github:nix-community/flake-firefox-nightly";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hass-tapo-control = {
      url = "github:JurajNyiri/homeAssistant-Tapo-Control";
      flake = false;
    };

    hass-oidc-auth = {
      url = "github:christiaangoossens/hass-oidc-auth";
      flake = false;
    };

    # Companion integration for the lovelace-idf-mobilite card. Pinned to the
    # v0.1.0 tag (early release) so the code matches manifest.json's version.
    idf-mobilite-assistant = {
      url = "github:yyrkoon94/idf-mobilite-assistant/v0.1.0";
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
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vicinae = {
      url = "github:vicinaehq/vicinae";
    };
    vicinae-extensions = {
      # Pinned: upstream commits after this rev exclude the "bluetooth"
      # extension from `packages`/`checks` (see their flake.nix removeAttrs
      # list) because it fails to build node-gyp's dbus-next -> usocket
      # native module against a newer nodejs/node-gyp toolchain. Confirmed
      # the extension still builds cleanly at this rev; bump only once
      # upstream's node-gyp issue is actually fixed, not just excluded.
      url = "github:vicinaehq/extensions/27d2b04f9ce48bdc69c29cd25d91d854fc8a835f";
    };
    vicinae-timezone-converter = {
      url = "github:CaptainSpof/vicinae-timezone-converter";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        vicinae.follows = "vicinae";
      };
    };

    # Vault Integration
    vault-service = {
      url = "github:DeterminateSystems/nixos-vault-service";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
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
          # "aspnetcore-runtime-6.0.36"
          # "emacs-unstable-pgtk-30.1"
          # "emacs-unstable-pgtk-with-packages-30.1"
          # "dotnet-sdk-6.0.428"
          # "qtwebengine-5.15.19"
          # "olm-3.2.16"
          "electron-40.10.5"
          "pnpm-10.29.2"
        ];
      };

      overlays = with inputs; [
        claude-desktop.overlays.default
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
