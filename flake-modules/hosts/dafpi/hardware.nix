{ config, ... }:
{
  configurations.nixos.dafpi.module =
    { lib, ... }:
    {
      imports = [ config.flake.modules.nixos.orangepi5 ];

      # One wired port; the networking aspect leaves DHCP to the host.
      networking.useNetworkd = true;
      systemd.network.networks."10-lan" = {
        matchConfig.Name = "en* eth*";
        networkConfig.DHCP = "yes";
        linkConfig.RequiredForOnline = "routable";
      };

      # 16 GB is plenty for the services planned here; this only catches
      # bursts (e.g. nix evaluating the whole fleet during a deploy).
      zramSwap.enable = true;

      powerManagement.cpuFreqGovernor = lib.mkDefault "schedutil";
    };
}
