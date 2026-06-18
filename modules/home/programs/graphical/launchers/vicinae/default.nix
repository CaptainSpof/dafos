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
    # HA long-lived token for the @tonka3000 extension. vicinae persists
    # password-type preferences in its SQLite store (storage_data_item), NOT
    # the config file, so the token can't be set declaratively via settings.
    # Keep it in sops and inject it into the DB on activation (see
    # home.activation.vicinaeHomeAssistantToken below). Token goes in
    # secrets/daf/vicinae.yaml.
    sops.secrets."vicinae-homeassistant-token".sopsFile =
      lib.snowfall.fs.get-file "secrets/daf/vicinae.yaml";

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
        font.normal.size = 12;
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
        launcher_window.opacity = 0.80;
        # Non-secret HA extension preferences. Provider id is
        # "@tonka3000/homeassistant" (not the raycast-store path). The token is
        # a password pref and lives in the SQLite store instead (see below).
        providers."@tonka3000/homeassistant".preferences = {
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

    # vicinae only stores password preferences (the HA API token) in its SQLite
    # store, normally set via the GUI — not the config file. Inject it from the
    # sops secret so it's reproducible. Runs after sops renders the secret, only
    # writes when the value differs, and restarts vicinae so it re-reads.
    home.activation.vicinaeHomeAssistantToken =
      config.lib.dag.entryAfter [ "sops-nix" "writeBoundary" ] ''
        db="$HOME/.local/share/vicinae/vicinae.db"
        secret=${lib.escapeShellArg config.sops.secrets."vicinae-homeassistant-token".path}
        ns='@tonka3000/homeassistant:preferences'
        if [ -f "$db" ] && [ -s "$secret" ]; then
          current=$(${pkgs.sqlite}/bin/sqlite3 -readonly "$db" \
            "SELECT value FROM storage_data_item WHERE namespace_id='$ns' AND key='token';" 2>/dev/null || true)
          if [ "$current" != "$(cat "$secret")" ]; then
            run ${pkgs.systemd}/bin/systemctl --user stop vicinae.service || true
            run ${pkgs.sqlite}/bin/sqlite3 "$db" \
              "INSERT INTO storage_data_item (namespace_id,value_type,key,value) VALUES ('$ns',1,'token',CAST(readfile('$secret') AS TEXT)) ON CONFLICT(namespace_id,key) DO UPDATE SET value=excluded.value, value_type=1;"
            run ${pkgs.systemd}/bin/systemctl --user start vicinae.service || true
          fi
        fi
      '';
  };
}
