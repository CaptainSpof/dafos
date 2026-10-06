{
  description = "Here lies my shipwrecks. I mean fleet of hosts.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    # nixpkgs.url = "github:K900/nixpkgs/plasma-6.4";

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager";
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

    # Hardware Configuration
    nixos-hardware.url = "github:nixos/nixos-hardware";

    # Snowfall Lib (no longer used — kept temporarily so the generated nix
    # registry / /etc/nix/inputs only gain entries during the flake-parts
    # migration; remove in the cleanup phase)
    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Flake framework (snowfall replacement)
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    # Auto-import of flake-modules/ (dendritic pattern)
    import-tree.url = "github:vic/import-tree";

    # Weekly updating nix-index database
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri.url = "github:epireyn/niri-flake";

    # Sonora — native music streaming client (Spotify/YouTube Music/local)
    sonora = {
      url = "github:nolight132/sonora";
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

    # Pinned to a tag so the manifest.json requirement pins (and the version
    # string in modules/nixos/services/home-assistant) only move deliberately —
    # tracking `main` broke the build when 7.1.27 moved to `pytapo==3.4.19`.
    hass-tapo-control = {
      url = "github:JurajNyiri/homeAssistant-Tapo-Control/7.1.27";
      flake = false;
    };

    idf-mobilite-assistant = {
      url = "github:yyrkoon94/idf-mobilite-assistant/v0.1.0";
      flake = false;
    };

    donetick-hass = {
      url = "github:donetick/donetick-hass-integration/3f3d27b3b46750bfba83b3c7ff6786d0581fe567";
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

    dank-calendar = {
      url = "github:AvengeMedia/DankCalendar";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Our own DMS plugin: spelling/grammar (LanguageTool) and offline
    # translation. Developed in ~/Projects/dms-proofreader.
    dms-proofreader = {
      url = "github:CaptainSpof/dms-proofreader";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vicinae = {
      url = "github:vicinaehq/vicinae";
      inputs.nixpkgs.follows = "nixpkgs";
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
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ (inputs.import-tree ./flake-modules) ];
    };
}
