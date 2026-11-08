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
      # Steam Deck (SteamOS). MagicDNS name: works on the LAN and away.
      # See ./AGENTS.md for what can be done on it.
      matchBlocks."dafdeck deck" = {
        hostname = "dafdeck";
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
