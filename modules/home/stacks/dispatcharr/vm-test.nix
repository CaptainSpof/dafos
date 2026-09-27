# Boot test (see tests/integration/vm.nix). The rest of the streaming stack is
# nps's to test, so Jellyfin and the qbittorrent/prowlarr stacks it pulls in by
# default are switched off; nps's default-on arrs still boot alongside.
_: {
  imports = [ ./default.nix ];

  nps.stacks.streaming = {
    enable = true;
    useQbittorrent = false;
    useProwlarr = false;
    jellyfin.enable = false;

    dispatcharr.enable = true;
  };
}
