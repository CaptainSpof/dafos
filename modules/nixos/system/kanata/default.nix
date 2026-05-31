{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib)
    concatStringsSep
    length
    mkIf
    optionalString
    pipe
    types
    ;
  inherit (lib.${namespace}) mkOpt mkBoolOpt;

  cfg = config.${namespace}.system.kanata;

  readPart = path: builtins.readFile (./. + "/${path}");

  defsrcFile = "defsrc/pc_anglemod.kbd";
  baseFile = "deflayer/base_lt_hrm.kbd";
  symbolsFile = "deflayer/symbols_noop_num.kbd";
  navigationFile = "deflayer/navigation_vim.kbd";
  layoutAliasFile = "defalias/ergol_pc.kbd";
in
{
  options.${namespace}.system.kanata = {
    enable = mkBoolOpt false "Whether or not to configure kanata.";
    excludedDevices = mkOpt (types.listOf types.str) [
      "ZMK Project Kyria Keyboard"
      "Glove80 Keyboard"
      "MoErgo Glove80 Left Keyboard"
      "Logitech G502"
      "LogiOps Virtual Input"
      "Espanso virtual device"
      "WH-1000XM3 (AVRCP)"
    ] "The devices to be excluded.";
    tapTimeout = mkOpt types.number 200 "Arsenik tap_timeout: key must be pressed twice within this many ms to enable repetitions.";
    holdTimeout = mkOpt types.number 200 "Arsenik hold_timeout: key must be held this many ms to become a layer shift.";
    longHoldTimeout = mkOpt types.number 300 "Arsenik long_hold_timeout: slightly higher value for typing keys, to prevent unexpected hold effect.";
  };

  config = mkIf cfg.enable {

    environment.systemPackages = with pkgs; [ kanata ];

    services.kanata = {
      enable = true;

      keyboards."ergol" =
        let
          mkExcludedDevices =
            devices:
            let
              devicesString = pipe devices [
                (map (device: "\"" + device + "\""))
                (concatStringsSep " ")
              ];
            in
            optionalString ((length devices) > 0) "linux-dev-names-exclude (${devicesString})";
        in
        {
          extraDefCfg = ''
            ${mkExcludedDevices cfg.excludedDevices}
            linux-device-detect-mode keyboard-only
            process-unmapped-keys yes
          '';
          config = ''
            ;; Timing variables for tap-hold effects.
            (defvar
              tap_timeout       ${toString cfg.tapTimeout}
              hold_timeout      ${toString cfg.holdTimeout}
              long_hold_timeout ${toString cfg.longHoldTimeout}
            )

            ;; -- defsrc --
            ${readPart defsrcFile}

            ;; -- base layer --
            ${readPart baseFile}

            ;; -- symbols layer --
            ${readPart symbolsFile}

            ;; -- navigation layer --
            ${readPart navigationFile}

            ;; -- layout aliases (Ergo-L PC) --
            ${readPart layoutAliasFile}

            ;; Application launcher shortcut for navigation layer ([Space]+[P])
            (defalias run XX)
          '';
        };
    };
  };
}
