# The single user (daf) on both sides: the NixOS account and its
# home-manager profile. Both declare `dafos.user.*`, each in its own
# option namespace.
{
  flake.modules.nixos.user =
    {
      config,
      pkgs,
      lib,
      ...
    }:

    let
      inherit (lib) types mkOption;

      cfg = config.dafos.user;

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
      options.dafos.user = {
        name = mkOption {
          type = types.str;
          default = username;
          description = "The name to use for the user account.";
        };
        fullName = mkOption {
          type = types.str;
          default = "Cédric Da Fonseca";
          description = "The full name of the user.";
        };
        email = mkOption {
          type = types.str;
          default = "dafonseca.cedric@gmail.com";
          description = "The email of the user for git.";
        };
        home = mkOption {
          type = types.nullOr types.str;
          default = "/home/${username}";
          description = "The user's home directory.";
        };

        initialPassword = mkOption {
          type = types.str;
          default = "omgchangeme";
          description = "The initial password to use when the user is first created.";
        };
        # Per-host: `dafos.user.icon = ./avatar.jpg;` in the host's files.
        icon = mkOption {
          type = types.nullOr types.path;
          default = ./_assets/user/profile.png;
          description = "The avatar (profile picture) to use for the user, or null to leave whatever AccountsService already holds.";
        };

        authorizedKeys = mkOption {
          type = types.listOf types.str;
          default = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP7YCmRYdXWhNTGWWklNYrQD5gUBTFhvzNiis5oD1YwV daf@daftop"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDU0z8wC6aL3EelbY83Ucj1+2TMKt+lKjQkzEH6jFaWu daf@dafoltop"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILGBJKhslXRQ4Bt8Nu3/YK799UsUpzpP6sDVkVw36nLR daf@dafpi"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM9pWuxUUYo7wwCIfMUkrlfyrpT4IDeWnqldrgm6TIl0 daf@dafbox"
          ];
          description = "The public keys to apply.";
        };

        extraGroups = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Groups for the user to be assigned.";
        };
        extraOptions = mkOption {
          type = types.attrs;
          default = { };
          description = "Extra options passed to `users.users.<name>`.";
        };
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
    };

  flake.modules.homeManager.user =
    {
      lib,
      config,
      ...
    }:

    let
      inherit (lib)
        types
        mkIf
        mkDefault
        mkMerge
        mkOption
        ;

      cfg = config.dafos.user;
      opt = type: default: description: mkOption { inherit type default description; };

      dirs = rec {
        config = "${home}/.config";
        documents = "${home}/Documents";
        download = "${home}/Downloads";
        home = "/home/${username}";
        music = "${home}/Music";
        org = "${sync}/Org";
        pictures = "${home}/Pictures";
        screenshots = "${home}/Pictures/Screenshots";
        projects = "${home}/Projects";
        repositories = "${home}/Repositories";
        sync = "${home}/Sync";
        templates = home;
        videos = "${home}/Videos";
      };
      username = "daf";
      home-directory = if cfg.name == null then null else "/home/${cfg.name}";
    in
    {

      options.dafos.user = {
        enable = opt types.bool false "Whether to configure the user account.";
        # snowfallorg.user only exists on legacy hosts (compat layer).
        name = opt (types.nullOr types.str) (config.snowfallorg.user.name or "daf") "The user account.";

        fullName = opt types.str "Cédric Da Fonseca" "The full name of the user.";
        email = opt types.str "dafonseca.cedric@gmail.com" "The email of the user.";
        gitEmail = opt types.str "captain.spof@gmail.com" "The email of the user for git.";
        gitUsername = opt types.str "CaptainSpof" "The username for git.";

        theme.dark = opt types.str "Everforest Dark Soft" "Dark theme to use for the system.";
        theme.light = opt types.str "Everforest Light Soft" "Light theme to use for the system.";

        font.mono = opt types.str "Departure Mono" "Mono Font to use for the system.";
        font.ui = opt types.str "Inter" "UI Font to use for the system.";

        location.latitude = opt types.str "48.89" "The latitude of the user.";
        location.longitude = opt types.str "2.21" "The longitude of the user.";
        location.name =
          opt types.str "Nanterre, France"
            "Human-readable name of the user's location (e.g. the DMS weather label).";

        home = opt (types.nullOr types.str) home-directory "The user's home directory.";
      };

      config = mkIf cfg.enable (mkMerge [
        {
          assertions = [
            {
              assertion = cfg.name != null;
              message = "dafos.user.name must be set";
            }
            {
              assertion = cfg.home != null;
              message = "dafos.user.home must be set";
            }
          ];

          xdg.userDirs = {
            enable = true;
            createDirectories = true;
            # Keep exporting $XDG_*_DIR (and the extraConfig vars below) into the
            # session. The HM default flipped to false in stateVersion 26.05; pin
            # the legacy behavior explicitly to silence the warning.
            setSessionVariables = true;
            inherit (dirs)
              documents
              download
              music
              pictures
              templates
              videos
              ;
            extraConfig = {
              ORG = dirs.org;
              PROJECTS = dirs.projects;
              REPOSITORIES = dirs.repositories;
              SCREENSHOTS = dirs.screenshots;
              SYNC = dirs.sync;
            };
          };

          home = {
            username = mkDefault cfg.name;
            homeDirectory = mkDefault cfg.home;

            # The NixOS `home-manager` module drives this from `system.stateVersion`
            # (see the `home` aspect), which outranks this default. It exists so
            # standalone home-manager evaluations -- which never see a NixOS
            # `config` -- can evaluate at all.
            stateVersion = mkDefault "23.11";
          };
        }
      ]);
    };
}
