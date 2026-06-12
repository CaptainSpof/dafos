{
  config,
  lib,
  namespace,
  inputs,
  pkgs,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.programs.graphical.launchers.vicinae;

  vicinaeExtensions = inputs.vicinae-extensions.packages.${pkgs.stdenv.hostPlatform.system};

  # Upstream's bluetooth extension resolves device names as `Name ?? Alias`, so
  # it shows the hardware name rather than the BlueZ alias. Flip the precedence
  # to prefer the friendly alias.
  bluetooth-alias-first = vicinaeExtensions.bluetooth.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/bluez/discovery.ts \
        --replace-fail 'devProps.Name ?? devProps.Alias' 'devProps.Alias ?? devProps.Name' \
        --replace-fail 'ifaces.Name ?? ifaces.Alias' 'ifaces.Alias ?? ifaces.Name'
    '';
  });
in
{
  options.${namespace}.programs.graphical.launchers.vicinae = {
    enable = mkBoolOpt false "Whether or not to use vicinae";
  };

  config = mkIf cfg.enable {
    programs.vicinae = {
      enable = true;
      systemd = {
        enable = true;
        autoStart = true;
      };
      settings = {
        keybinding_scheme = "Emacs";
        close_on_focus_loss = true;
        consider_preedit = true;
        pop_to_root_on_close = true;
        favicon_service = "twenty";
        search_files_in_root = true;
        font = {
          normal = {
            size = 12;
          };
        };
        theme = {
          light = {
            name = "vicinae-light";
            icon_theme = "default";
          };
          dark = {
            name = "vicinae-dark";
            icon_theme = "default";
          };
        };
        launcher_window = {
          opacity = 0.80;
        };
        # Extension preferences. Vicinae reads non-secret extension prefs from
        # this config file; because it's a read-only Nix store path, vicinae
        # can't persist them itself, so the Home Assistant server URL is set
        # here. The provider key is the runtime id `@<author>/<install-dir>`
        # (verified via `vicinae deeplink vicinae://launch/<id>/lights`). The
        # long-lived token is a secret and is entered once in the UI — vicinae
        # stores it in its separate, writable secret store, not in this file.
        providers."@tonka3000/store.raycast.homeassistant".preferences = {
          instance = "https://home.daftdaf.dev";
        };
      };
      extensions = [
        bluetooth-alias-first
      ] ++ (with vicinaeExtensions; [
        firefox
        it-tools
        nix
        power-profile
        wifi-commander
      ]) ++ [
        # (config.lib.vicinae.mkRayCastExtension {
        #   name = "tailscale";
        #   rev = "bc92e53ae972e41a44800b2a4763a5b7bf69122e";
        #   sha256 = "sha256-7Fc/qengMNQFVM42Qvea7gn+HbEJs5Pgmu87f3RUPeg=";
        # })
      ];
    };
  };
}
