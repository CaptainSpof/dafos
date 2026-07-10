{
  config,
  lib,
  namespace,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.system.gtkHmGuard;
in
{
  options.${namespace}.system.gtkHmGuard = {
    enable = mkBoolOpt false "Whether or not to guard ~/.gtkrc-2.0 against home-manager activation failures caused by KDE's kded gtkconfig module.";
  };

  # Any KDE/KIO app (Dolphin, Ark, ...) D-Bus-activates kded6, even outside a
  # full Plasma session. kded6's gtkconfig module then rewrites ~/.gtkrc-2.0
  # as a plain file to mirror Plasma's GTK theme settings, turning the
  # home-manager-managed symlink into a regular file. The next activation
  # backs that file up to *.hm.old; once a backup already exists, HM refuses
  # to clobber it and the whole activation aborts ("would be clobbered by
  # backing up"). Drop the live file and any stale backup before HM links, so
  # there is nothing to back up. kded6 regenerates ~/.gtkrc-2.0 on its own
  # the next time it starts.
  config = mkIf cfg.enable {
    home.activation.dropKdeGtkrcClobber = config.lib.dag.entryBefore [ "checkLinkTargets" ] ''
      run rm -f "$HOME/.gtkrc-2.0" "$HOME/.gtkrc-2.0.hm.old"
    '';
  };
}
