{
  config,
  lib,
  namespace,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.system.xkb;
in
{
  options.${namespace}.system.xkb = {
    enable = mkBoolOpt false "Whether or not to configure xkb.";
  };

  config = mkIf cfg.enable {
    console.useXkbConfig = true;
    services.xserver = {
      xkb = {
        layout = "fr";
        variant = "ergol";
        # compose:paus binds the otherwise-unused Pause key to Multi_key, so
        # kanata (defalias/ergol_accent.kbd) can reach Compose sequences that
        # have no dead-key route on fr(ergol), like œ/æ.
        options = "caps:escape,compose:paus";
      };
    };
  };
}
