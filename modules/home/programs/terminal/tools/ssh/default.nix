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
      # Without it Home Manager writes no ~/.ssh/config and everything below
      # is silently dropped.
      enable = true;
      # Upstream's implicit "Host *" defaults are deprecated: only what is
      # set below is written.
      enableDefaultConfig = false;
      # `settings` replaces the deprecated `matchBlocks`; keys are ssh_config
      # directives. Global options go in "*" (extraConfig would land inside
      # the last Host block).
      settings = {
        # Steam Deck (SteamOS). MagicDNS name: works on the LAN and away.
        # See ./AGENTS.md for what can be done on it.
        "dafdeck deck" = {
          HostName = "dafdeck";
          User = "deck";
          IdentityFile = "~/.ssh/daf@dafbox.pem";
          IdentitiesOnly = true;
        };
        "*".AddKeysToAgent = "yes";
      };
    };
  };
}
