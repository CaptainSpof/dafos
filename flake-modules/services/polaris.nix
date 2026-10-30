# Polaris game stream host (https://github.com/papi-ux/polaris), on trial as a
# Sunshine replacement. Its upstream modules are reused by path; the packages
# are built against our pkgs with CUDA off (the fleet is AMD, and upstream's
# overlay hardcodes cudaSupport = true).
#
# Upstream's default "gamescope_stream" mode streams a private headless
# gamescope, not the niri desktop, so it does not depend on the compositor.
{ inputs, ... }:
let
  src = inputs.polaris;
in
{
  flake.modules.nixos.polaris =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    let
      cfg = config.dafos.services.polaris;

      packages = {
        package =
          (pkgs.callPackage "${src}/nix/packages/polaris-stream" {
            # Same tag as the `polaris` input, with the third-party submodules
            # the input can't carry (see flake.nix). Bump both together.
            polarisSrc = pkgs.fetchgit {
              url = "https://github.com/papi-ux/polaris";
              rev = "a8db09c70ac147d1512e2b7d64dba2ddf95a01e8"; # v1.5.0-beta.2
              fetchSubmodules = true;
              hash = "sha256-UqhKYxnVfOM0VStHr0y49UzCPlZ8LYUyfp4VhIx4814=";
            };
            cudaSupport = false;
          }).overrideAttrs
            (old: {
              # Upstream only adds vulkan-headers alongside CUDA, but cmake
              # find_package(Vulkan)s unconditionally.
              buildInputs = old.buildInputs ++ [ pkgs.vulkan-headers ];
              # The HM module's polaris-gamescope-session wrapper (it exports
              # POLARIS_GAMESCOPE_BIN) must shadow the package's own copy.
              meta = old.meta // {
                priority = 6;
              };
            });
        packageGamescope = pkgs.callPackage "${src}/nix/packages/gamescope-polaris" { };
        packagePortal = pkgs.callPackage "${src}/nix/packages/xdg-desktop-portal-gamescope" { };
      };

      # Upstream's HM module, with its scripts built under a shellcheck that
      # tolerates SC2030/SC2031 (info-level subshell-export notes in
      # polaris-gamescope-session that our newer shellcheck makes fatal).
      hmModule =
        { pkgs, ... }@args:
        import "${src}/nix/modules/home-manager.nix" (
          args
          // {
            pkgs = pkgs // {
              writeShellApplication =
                app:
                pkgs.writeShellApplication (
                  app
                  // {
                    excludeShellChecks = (app.excludeShellChecks or [ ]) ++ [
                      "SC2030"
                      "SC2031"
                    ];
                  }
                );
            };
          }
        )
        // {
          _file = "${src}/nix/modules/home-manager.nix";
        };
    in
    {
      options.dafos.services.polaris = {
        enable = lib.mkEnableOption "the Polaris game stream host";
        gpu = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "1002:747e";
          description = ''
            PCI vendor:device of the GPU the headless gamescope renders on.
            null keeps the OS device order, which on hosts with an iGPU can
            pick the iGPU. The encoder GPU is chosen separately in the web UI.
          '';
        };
      };

      # Upstream's nix/modules/nixos.nix, inlined: it declares
      # `services.polaris`, which nixpkgs already owns (the music server).
      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = !config.services.sunshine.enable;
            message = "Polaris and Sunshine bind the same GameStream ports; enable only one.";
          }
        ];

        environment.systemPackages = builtins.attrValues packages;

        hardware.uinput.enable = true;
        boot.kernelModules = [ "uhid" ];
        services.udev.packages = [ packages.package ];

        # Discovery (_nvstream); the avahi aspect already enables publishing.
        dafos.services.avahi.enable = lib.mkDefault true;

        networking.firewall = {
          allowedTCPPorts = [
            47984
            47989
            47990
            48010
          ];
          allowedUDPPorts = [
            47998
            47999
            48000
            48010
          ];
        };

        users.users.${config.dafos.user.name}.extraGroups = [
          "audio"
          "uinput"
          "video"
          "render"
          "input"
        ];

        home-manager.users.${config.dafos.user.name} = hm: {
          imports = [ hmModule ];

          services.polaris = packages // {
            enable = true;
            preferVkDevice = cfg.gpu;
          };

          # Upstream seeds polaris.conf with encoder = nvenc. Seed the same file
          # with VAAPI first (only when missing, like upstream: the web UI owns
          # later edits), so the upstream seed step finds it and skips.
          home.activation.polarisConfSeedVaapi = hm.lib.hm.dag.entryBefore [ "polarisConfSeed" ] ''
            confdir="$HOME/.config/polaris"
            if [ ! -f "$confdir/polaris.conf" ]; then
              mkdir -p "$confdir"
              install -m 600 ${pkgs.writeText "polaris.conf" ''
                headless_mode = enabled
                linux_use_cage_compositor = enabled
                linux_prefer_gpu_native_capture = disabled
                linux_stream_mode = gamescope_stream
                capture = portal
                encoder = vaapi
                hevc_mode = 3
                av1_mode = 0
                stream_audio = enabled
                enable_pairing = enabled
                enable_discovery = enabled
                max_sessions = 2
              ''} "$confdir/polaris.conf"
            fi
          '';
        };
      };
    };
}
