{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.programs.terminal.tools.podman-tui;
in
{
  options.${namespace}.programs.terminal.tools.podman-tui = {
    enable = mkBoolOpt false "Whether or not to enable podman-tui.";
  };

  # podman-tui talks to the podman API socket rather than shelling out, so it
  # needs `podman.socket` running in whichever session owns the containers:
  # the user unit for rootless stacks (nps/quadlet enables it), the system one
  # for root containers (dafos.virtualisation.podman turns that on).
  config = mkIf cfg.enable {
    home = {
      packages = with pkgs; [ podman-tui ];

      shellAliases = {
        # #
        # Podman aliases
        # #
        pcd = "podman-compose down";
        pcu = "podman-compose up -d";
        pim = "podman images";
        pps = "podman ps";
        ppsa = "podman ps -a";
        psp = "podman system prune --all";
        pt = "podman-tui";
      };
    };
  };
}
