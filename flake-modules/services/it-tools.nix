# IT-Tools (nps stack): stateless developer utilities, private (LAN/tailnet).
# Runs on dafpi, the pilot for moving light services off dafoltop.
{
  flake.modules.homeManager.it-tools =
    { config, lib, ... }:
    {
      options.dafos.services.it-tools.enable = lib.mkEnableOption "IT-Tools";

      config = lib.mkIf config.dafos.services.it-tools.enable {
        nps.stacks.it-tools.enable = true;
      };
    };
}
