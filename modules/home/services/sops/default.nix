{
  config,
  lib,
  namespace,
  pkgs,
  ...
}:

let
  inherit (lib) mkIf types;
  inherit (lib.${namespace}) mkBoolOpt mkOpt;

  cfg = config.${namespace}.services.sops;

  ageKeyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

  # snowfall's extended lib does not carry home-manager's `lib.hm`; the DAG
  # helpers are exposed on `config.lib` instead.
  inherit (config.lib) dag;
in
{
  options.${namespace}.services.sops = with types; {
    enable = mkBoolOpt true "Whether to enable sops.";
    defaultSopsFile = mkOpt path null "Default sops file.";
    sshKeyPaths = mkOpt (listOf path) [ ] "SSH Key paths to use.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      age
      sops
      ssh-to-age
      openssl
    ];

    sops = {
      inherit (cfg) defaultSopsFile;
      defaultSopsFormat = "yaml";

      age = {
        # Fallback only, for hosts that declare no sshKeyPaths. sops-nix runs
        # `age-keygen` whenever keyFile is absent, and the identity it invents is
        # authorized nowhere, so the activation step below gets there first.
        generateKey = true;
        keyFile = ageKeyFile;
        # Each host declares its own SSH key in its home config; the derived
        # age identity must be authorized in .sops.yaml.
        inherit (cfg) sshKeyPaths;
      };
    };

    # Keep the age identity the `sops` CLI reads in sync with the one sops-nix
    # actually decrypts with.
    #
    # sops-nix uses two different identities without reconciling them: at
    # activation `sops-install-secrets` derives one from `age.sshKeyPaths`, while
    # the `sops` CLI only ever reads `age.keyFile`. Because `generateKey` fills a
    # missing keyFile with a *random* `age-keygen` identity, a fresh host ends up
    # with working secrets but a CLI that cannot decrypt anything — the identity
    # in keyFile is not the one .sops.yaml authorizes. That is what happened on
    # dafbox (keys.txt generated 2026-02-05, authorized nowhere).
    #
    # Running before the `sops-nix` entry means keyFile already exists by the time
    # sops-nix would generate one, so `generateKey` stays inert on these hosts.
    # The previous file is kept as a timestamped .bak rather than dropped, since
    # an unrecognised identity here might still be someone's only copy.
    home.activation.sopsAgeKeyFromSshKey = mkIf (cfg.sshKeyPaths != [ ]) (
      dag.entryBefore [ "sops-nix" ] ''
        ageKeyFile=${lib.escapeShellArg ageKeyFile}
        derived=""

        for sshKey in ${lib.concatMapStringsSep " " lib.escapeShellArg cfg.sshKeyPaths}; do
          if [ -r "$sshKey" ]; then
            derived="$(${lib.getExe pkgs.ssh-to-age} -private-key -i "$sshKey" 2>/dev/null)" || derived=""
            [ -n "$derived" ] && break
          fi
        done

        if [ -n "$derived" ]; then
          want="$(printf '%s\n' "$derived" | ${pkgs.age}/bin/age-keygen -y /dev/stdin 2>/dev/null)" || want=""
          have=""
          if [ -f "$ageKeyFile" ]; then
            have="$(${pkgs.age}/bin/age-keygen -y "$ageKeyFile" 2>/dev/null)" || have=""
          fi

          if [ -n "$want" ] && [ "$want" != "$have" ]; then
            run ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$ageKeyFile")"

            if [ -f "$ageKeyFile" ]; then
              run ${pkgs.coreutils}/bin/cp -a "$ageKeyFile" \
                "$ageKeyFile.bak-$(${pkgs.coreutils}/bin/date +%Y%m%d%H%M%S)"
            fi

            tmp="$(${pkgs.coreutils}/bin/mktemp)"
            ${pkgs.coreutils}/bin/chmod 600 "$tmp"
            printf '%s\n' "$derived" > "$tmp"
            run ${pkgs.coreutils}/bin/mv -f "$tmp" "$ageKeyFile"
            ${pkgs.coreutils}/bin/rm -f "$tmp"

            echo "sops: age identity in $ageKeyFile now derived from $sshKey ($want)"
          fi
        fi
      ''
    );

    # A private key, whichever way it got there: `cp -a` above keeps the mode
    # of whatever it backs up, and dafoltop's keys.txt had been 0644 since it
    # was put there by hand.
    home.activation.sopsAgeKeyPermissions = dag.entryAfter [ "sopsAgeKeyFromSshKey" ] ''
      for f in ${lib.escapeShellArg ageKeyFile} ${lib.escapeShellArg ageKeyFile}.bak-*; do
        [ -f "$f" ] && run ${pkgs.coreutils}/bin/chmod 600 "$f"
      done
      true
    '';

    # Containers read their secrets when they start, and sops-nix.service (a
    # oneshot) is only ordered before the ones that remembered to say so. The rest
    # race it: on 2026-10-01 bar-assistant-meilisearch started 2 s before the
    # secrets existed, exited on an empty master key, and its dependents stayed
    # down. authelia, lldap and immich-kiosk read secrets too.
    #
    # A dash-truncated drop-in applies to every `podman-*.service` unit, present
    # and future, so no list of container names has to be kept in step. It is
    # `After=` only, not `Wants=`: a oneshot that has finished is inactive, and
    # `Wants=` would re-run the decryption on every later container restart.
    # sd-switch only reads each unit's own `.service.d`, so adding this restarts
    # nothing on a switch; it takes effect from the next boot.
    xdg.configFile."systemd/user/podman-.service.d/10-after-sops-nix.conf".text = ''
      [Unit]
      After=sops-nix.service
    '';
  };
}
