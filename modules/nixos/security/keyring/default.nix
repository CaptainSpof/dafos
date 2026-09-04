{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib) mkForce mkIf;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.security.keyring;
in
{
  options.${namespace}.security.keyring = {
    enable = mkBoolOpt false "Whether to enable gnome keyring.";
  };

  config = mkIf cfg.enable {
    # niri's nixpkgs module already flips this on (mkDefault), as does gnome —
    # set it explicitly so the keyring doesn't silently depend on which
    # compositor happens to be enabled. This is what adds pam_gnome_keyring to
    # the login PAM stack and pulls in the daemon itself.
    services.gnome.gnome-keyring.enable = true;

    environment.systemPackages = with pkgs; [
      # GUI keyring manager. Also the only practical way to change (or blank)
      # the login keyring's password — needed on autologin hosts, where PAM
      # never sees a password and so can't unlock the keyring for you.
      seahorse
      # `secret-tool`, for reading/writing the Secret Service from a shell.
      libsecret
    ];

    # Keep KWallet out of the way where gnome-keyring is the secret store.
    # plasma6 is installed here for its apps and as an alternate session, so any
    # KDE app (okular, kdeconnect, signond…) D-Bus-activates kwalletd6 mid-niri
    # session, which then starts ksecretd — a second credential store that will
    # grow its own password prompt as soon as something writes to it. There is
    # no name clash today (gnome-keyring owns org.freedesktop.secrets, and
    # kwallet's portal backend is UseIn=kde, so it never serves niri), just two
    # stores where one will do.
    #
    # KWallet::Wallet::isEnabled() reads this client-side, so apps skip the
    # wallet without ever activating the daemon. /etc/xdg is the system tier of
    # the KConfig cascade — ~/.config/kwalletrc still overrides it per-user.
    environment.etc."xdg/kwalletrc".text = ''
      [Wallet]
      Enabled=false
    '';

    # plasma6 puts pam_kwallet5 in the login stack unconditionally. With no
    # wallet to unlock it is dead weight, and under autologin it never had a
    # password to unlock one with anyway.
    security.pam.services.login.kwallet.enable = mkForce false;
  };
}
