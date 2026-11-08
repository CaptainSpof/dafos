{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.${namespace}.programs.terminal.tools.ssh;
in
{
  options.${namespace}.programs.terminal.tools.ssh = {
    enable = mkEnableOption "Whether or not to enable ssh.";
  };

  config = mkIf cfg.enable {
    programs.ssh = {
      # Steam Deck (SteamOS, sshd enabled by hand). The address is a LAN IP:
      # reserve it on the Freebox or switch to the tailnet name.
      matchBlocks."dafdeck deck" = {
        hostname = "192.168.0.30";
        user = "deck";
        identityFile = "~/.ssh/daf@dafbox.pem";
        identitiesOnly = true;
      };
      extraConfig = ''
        AddKeysToAgent yes
      '';
    };
  };
}
