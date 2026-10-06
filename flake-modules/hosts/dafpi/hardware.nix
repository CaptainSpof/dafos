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
        # Fixed interface id on whatever /64 the Freebox advertises, so the
        # address blocky listens on (and the Freebox points at) is stable:
        # 2a01:e0a:b6c:4b90::15 for the current Free prefix.
        ipv6AcceptRAConfig.Token = "static:::15";
      };

      # 16 GB is plenty for the services planned here; this only catches
      # bursts (e.g. nix evaluating the whole fleet during a deploy).
      zramSwap.enable = true;

      powerManagement.cpuFreqGovernor = lib.mkDefault "schedutil";
    };
}
