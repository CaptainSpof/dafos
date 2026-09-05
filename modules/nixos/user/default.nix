{
  config,
  pkgs,
  lib,
  namespace,
  ...
}:

let
  inherit (lib) types mdDoc;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.user;

  # The avatar, exposed at a stable path under /run/current-system/sw instead
  # of a bare store path: it gets written into AccountsService's stateful ini
  # below, so a path that doesn't move on every rebuild is easier to live with.
  iconFileName = baseNameOf cfg.icon;
  propagatedIcon = pkgs.runCommand "propagated-icon" { } ''
    target="$out/share/dafos-icons/user/${cfg.name}"
    mkdir -p "$target"

    cp ${cfg.icon} "$target/${iconFileName}"
  '';
  iconFile = "/run/current-system/sw/share/dafos-icons/user/${cfg.name}/${iconFileName}";

  username = "daf";
  shell = pkgs.fish;
in
{
  options.${namespace}.user = {
    name = mkOpt types.str username "The name to use for the user account.";
    fullName = mkOpt types.str "Cédric Da Fonseca" "The full name of the user.";
    email = mkOpt types.str "dafonseca.cedric@gmail.com" "The email of the user for git.";
    home = mkOpt (types.nullOr types.str) "/home/${username}" "The user's home directory.";

    initialPassword =
      mkOpt types.str "omgchangeme"
        "The initial password to use when the user is first created.";
    # Per-host: `dafos.user.icon = ./avatar.jpg;` in systems/<arch>/<host>.
    icon =
      mkOpt (types.nullOr types.path) ./profile.png
        "The avatar (profile picture) to use for the user, or null to leave whatever AccountsService already holds.";

    authorizedKeys = mkOpt (types.listOf types.str) [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP7YCmRYdXWhNTGWWklNYrQD5gUBTFhvzNiis5oD1YwV daf@daftop"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDU0z8wC6aL3EelbY83Ucj1+2TMKt+lKjQkzEH6jFaWu daf@dafoltop"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILGBJKhslXRQ4Bt8Nu3/YK799UsUpzpP6sDVkVw36nLR daf@dafpi"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM9pWuxUUYo7wwCIfMUkrlfyrpT4IDeWnqldrgm6TIl0 daf@dafbox"
    ] "The public keys to apply.";

    extraGroups = mkOpt (types.listOf types.str) [ ] "Groups for the user to be assigned.";
    extraOptions = mkOpt types.attrs { } (mdDoc "Extra options passed to `users.users.<name>`.");
  };

  config = {
    environment.systemPackages =
      (with pkgs; [
        fd
        fortune
        lolcat
      ])
      ++ lib.optional (cfg.icon != null) propagatedIcon;

    # AccountsService is where the avatar actually comes from for everything
    # graphical here: DMS asks it over D-Bus (`freedesktop.accounts.
    # getUserIconFile`) for the control-center header, the dash user card and
    # the lock screen, and the DMS greeter does the same per user. It answers
    # with the `Icon=` key of /var/lib/AccountsService/users/<name>, falling
    # back to /var/lib/AccountsService/icons/<name>.
    #
    # That file is stateful and shared (accounts-daemon also stores Language,
    # Session, … in it), so we rewrite just the one key rather than owning the
    # whole file. Done at activation, not from a unit, so a `nixos-rebuild
    # switch` applies it without waiting for the display manager.
    #
    # DMS's own avatar picker goes the other way: it makes accounts-daemon copy
    # the image to icons/<name> and repoints `Icon=` there, which activation
    # then overwrites. To keep an avatar picked in the GUI, copy
    # /var/lib/AccountsService/icons/<name> into the repo and point
    # `dafos.user.icon` at it.
    #
    # Only grep and coreutils are used: activation runs with PATH=/empty plus
    # coreutils, gnugrep, findutils, getent, shadow and util-linux — no gnused.
    # Dropping the Icon= line and re-appending it also avoids having to quote a
    # path into a sed replacement, which is what broke the first version of
    # this (and the gnome module it came from): the `$` anchor in
    # "s#^Icon=.*$#…#" was eaten by the shell as `$#` long before sed saw it.
    system.activationScripts.dafosUserIcon = lib.mkIf (cfg.icon != null) ''
      config_file=/var/lib/AccountsService/users/${cfg.name}

      mkdir -p "$(dirname "$config_file")"

      if [ ! -f "$config_file" ]; then
        # Match the 0600 accounts-daemon creates these with.
        install -m 0600 /dev/null "$config_file"
        printf '[User]\nSystemAccount=false\n' > "$config_file"
      fi

      # Truncate in place rather than mv a temp file over it, so the mode and
      # ownership accounts-daemon set are preserved.
      icon_rest=$(grep -v '^Icon=' "$config_file" || true)
      printf '%s\nIcon=%s\n' "$icon_rest" ${lib.escapeShellArg iconFile} > "$config_file"
    '';

    programs.fish.enable = true;

    users.users.${cfg.name} = {
      isNormalUser = true;

      inherit (cfg) home name initialPassword;
      inherit shell;

      group = "users";

      # Arbitrary user ID to use for the user. Since I only
      # have a single user on my machines this won't ever collide.
      # However, if you add multiple users you'll need to change this
      # so each user has their own unique uid (or leave it out for the
      # system to select).
      uid = 1000;

      extraGroups = [ "input" ] ++ cfg.extraGroups;
    }
    // cfg.extraOptions;
  };
}
