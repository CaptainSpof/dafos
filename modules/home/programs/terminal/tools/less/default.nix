{
  config,
  lib,
  namespace,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.programs.terminal.tools.less;
in
{
  options.${namespace}.programs.terminal.tools.less = {
    enable = mkBoolOpt false "Whether or not to enable less.";
  };

  config = mkIf cfg.enable {
    programs.less = {
      enable = true;
      config = ''
        l   next-tag
        L   prev-tag
        r   forw-line
        t   back-line
        R   forw-scroll
        T   back-scroll
      '';
    };
  };
}
