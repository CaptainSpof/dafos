{
  config,
  pkgs,
  lib,
  namespace,
  ...
}:

let
  inherit (lib) mkIf types;
  inherit (lib.${namespace}) mkOpt mkBoolOpt;

  cfg = config.${namespace}.system.fonts;
in
{
  options.${namespace}.system.fonts = with types; {
    enable = mkBoolOpt false "Whether or not to manage fonts.";
    fonts = mkOpt (listOf package) [ ] "Custom font packages to install.";
  };

  config = mkIf cfg.enable {
    environment.variables = {
      # Enable icons in tooling since we have nerdfonts.
      LOG_ICONS = "true";
    };

    fonts.packages =
      with pkgs;
      [
        nerd-fonts.monaspace
        nerd-fonts.hack
        departure-mono
        google-fonts
        julia-mono
        maple-mono.NF
        mononoki
        noto-fonts
        noto-fonts-emoji
        roboto
        roboto-mono
        sarasa-gothic
        # twemoji-color-font
      ]
      ++ cfg.fonts;
  };
}
