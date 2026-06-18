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

  # Home Assistant Raycast extension (@tonka3000) — not packaged in
  # vicinae-extensions, so build it from the raycast/extensions monorepo with
  # the vicinae mkRayCastExtension helper. The instance URL is configured via
  # programs.vicinae.settings.providers below. To update: bump rev and refresh
  # sha256 (it's the sparse-checkout hash of extensions/homeassistant; a build
  # on mismatch prints the correct value).
  homeassistant-extension =
    inputs.vicinae.lib.${pkgs.stdenv.hostPlatform.system}.mkRayCastExtension {
      name = "homeassistant";
      rev = "b1f5a90ffd31feb46c2f70d51328783f87a48680";
      sha256 = "sha256-QuaaX+M0oa7cbS/sQirhYHyqF8tGbqHxFQm7vv672p8=";
    };
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

        # Extension preferences
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
        niri
        power-profile
        wifi-commander
      ]) ++ [
        homeassistant-extension
      ];
    };
  };
}
