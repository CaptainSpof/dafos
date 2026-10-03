# Curried on `namespace`, like ./games.nix: snowfall only passes it to the
# modules it discovers itself.
{ namespace }:
{
  config,
  lib,
  pkgs,
  ...
}:
# The proofreader bar widget: a scratch text area checked by LanguageTool, with
# offline translation through Bergamot (translateLocally).
#
#   - ./plugins/proofreader is the DMS plugin; it talks to LanguageTool over
#     HTTP and shells out to `dms-translate` for translation;
#   - this module hands it its per-host defaults through a generated
#     proofreader.json, which the plugin's own settings override.
#
# The server itself is `dafos.services.languagetool` (NixOS); see its README
# for pointing a laptop at dafoltop instead of a local instance.
let
  inherit (lib)
    concatStringsSep
    filter
    mapAttrsToList
    mkIf
    splitString
    types
    unique
    ;
  inherit (lib.${namespace}) mkOpt mkBoolOpt;

  cfg = config.${namespace}.desktop.dms;
  proofCfg = cfg.proofreader;
  transCfg = proofCfg.translation;

  pluginSettingsFile = "${config.xdg.configHome}/DankMaterialShell/plugin_settings.json";

  # nixpkgs' translatelocally fails under gcc 16: marian's shared_ptr use trips
  # -Werror=array-bounds. The warning is a false positive in libstdc++ headers.
  translatelocally = pkgs.translatelocally.overrideAttrs (old: {
    env = (old.env or { }) // {
      NIX_CFLAGS_COMPILE = toString [
        (old.env.NIX_CFLAGS_COMPILE or "")
        "-Wno-error=array-bounds"
      ];
    };
  });

  # "fr-en-tiny" -> { src = "fr"; dst = "en"; code = "fr-en-tiny"; }
  parseModel =
    code:
    let
      parts = splitString "-" code;
    in
    {
      inherit code;
      src = builtins.elemAt parts 0;
      dst = builtins.elemAt parts 1;
    };

  # Base models win over tiny ones when both are listed for the same pair:
  # they sort first, and listToAttrs keeps the first occurrence of a name.
  models = map parseModel (
    (filter (lib.hasSuffix "-base") transCfg.models)
    ++ (filter (m: !lib.hasSuffix "-base" m) transCfg.models)
  );
  direct = builtins.listToAttrs (map (m: lib.nameValuePair "${m.src}-${m.dst}" m.code) models);

  langs = unique (
    lib.concatMap (m: [
      m.src
      m.dst
    ]) models
  );
  reachable =
    src: dst:
    src != dst && (direct ? "${src}-${dst}" || (direct ? "${src}-en" && direct ? "en-${dst}"));

  # What the plugin's target menu offers for a given source language.
  translationPairs = lib.genAttrs langs (src: filter (reachable src) langs);

  modelData = pkgs.symlinkJoin {
    name = "translatelocally-models-dms";
    paths = map (code: pkgs.translatelocally-models.${code}) transCfg.models;
  };

  translate = pkgs.writeShellApplication {
    name = "dms-translate";
    runtimeInputs = [ translatelocally ];
    text = ''
      # dms-translate SRC DST [TEXT]  -- TEXT, or stdin when omitted.
      # Pairs without a model of their own go through English.
      declare -A model=(
        ${concatStringsSep "\n    " (mapAttrsToList (pair: code: "[${pair}]=${code}") direct)}
      )

      if [ $# -lt 2 ]; then
        echo "usage: dms-translate SRC DST [TEXT]" >&2
        exit 64
      fi
      src=$1 dst=$2
      shift 2
      if [ $# -gt 0 ]; then text=$1; else text=$(cat); fi

      export XDG_DATA_DIRS=${modelData}/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}
      export LC_ALL=C.UTF-8 QT_QPA_PLATFORM=offscreen

      tl() { translateLocally -m "$1" 2>/dev/null; }

      if [ -n "''${model[$src-$dst]:-}" ]; then
        printf '%s\n' "$text" | tl "''${model[$src-$dst]}"
      elif [ -n "''${model[$src-en]:-}" ] && [ -n "''${model[en-$dst]:-}" ]; then
        printf '%s\n' "$text" | tl "''${model[$src-en]}" | tl "''${model[en-$dst]}"
      else
        echo "no translation model for $src -> $dst" >&2
        exit 2
      fi
    '';
  };

  pluginDefaults = (pkgs.formats.json { }).generate "proofreader.json" {
    inherit (proofCfg) languageToolUrl;
    translateBin = if transCfg.enable then lib.getExe translate else "";
    translationPairs = if transCfg.enable then translationPairs else { };
  };
in
{
  options.${namespace}.desktop.dms.proofreader = {
    enable = mkBoolOpt false ''
      Add the proofreader widget to DMS: a text area checked by LanguageTool,
      with optional offline translation.
    '';

    languageToolUrl = mkOpt types.str "http://127.0.0.1:8081" ''
      LanguageTool server the widget checks against. The default is the local
      `dafos.services.languagetool`; a laptop can point at dafoltop instead.
    '';

    translation = {
      enable = mkBoolOpt true "Offer offline translation (Bergamot via translateLocally).";

      models = mkOpt (types.listOf (types.enum (builtins.attrNames pkgs.translatelocally-models))) [
        "fr-en-tiny"
        "en-fr-tiny"
        "de-en-tiny"
        "en-de-tiny"
        "es-en-tiny"
        "en-es-tiny"
      ] "translatelocally-models to install. Pairs without a direct model are chained through English.";
    };
  };

  config = mkIf (cfg.enable && proofCfg.enable) {
    home.packages = lib.optional transCfg.enable translate;

    programs.dank-material-shell.plugins.proofreader.src = ./plugins/proofreader;

    xdg.configFile."DankMaterialShell/proofreader.json".source = pluginDefaults;

    # Plugin enable-state is runtime-owned (see ./plugins.nix); seed it once,
    # then leave the toggle to the DMS UI.
    home.activation.dmsProofreaderPlugin = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      settings=${lib.escapeShellArg pluginSettingsFile}
      run mkdir -p "$(dirname "$settings")"
      [ -f "$settings" ] || run sh -c "echo '{}' > \"$settings\""
      if [ "$(${pkgs.jq}/bin/jq -r 'has("proofreader")' "$settings")" != "true" ]; then
        tmp=$(mktemp)
        ${pkgs.jq}/bin/jq '.proofreader = { "enabled": true }' "$settings" > "$tmp" \
          && run mv "$tmp" "$settings"
      fi
    '';
  };
}
