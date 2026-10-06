{ inputs, ... }:
{
  flake.modules.nixos.openssh =
    {
      config,
      lib,
      ...
    }:

    let
      inherit (lib)
        optionalString
        mkIf
        mkOption
        types
        ;
      inherit (config.dafos.user) authorizedKeys;

      cfg = config.dafos.services.openssh;

      name = config.networking.hostName;

      other-hosts = lib.filterAttrs (
        key: host: key != name && (host.config.dafos.user.name or null) != null
      ) (inputs.self.nixosConfigurations or { });

      other-hosts-config = lib.concatMapStringsSep "\n" (
        other:
        let
          remote = other-hosts.${other};
          remote-user-name = remote.config.dafos.user.name;
        in
        ''
          Host ${other}
            IdentityFile ~/.ssh/daf@${name}.pem
            IdentitiesOnly yes
            ControlMaster auto
            ControlPath ~/.ssh/control-%r@%h:%p
            ControlPersist 10m
            User ${remote-user-name}
            Port ${builtins.toString cfg.port}
        ''
      ) (builtins.attrNames other-hosts);
    in
    {
      options.dafos.services.openssh = {
        enable = lib.mkEnableOption "OpenSSH support";
        port = mkOption {
          type = types.port;
          default = 2222;
          description = "The port to listen on (in addition to 22).";
        };
        manage-other-hosts = mkOption {
          type = types.bool;
          default = true;
          description = "Whether or not to add other host configurations to SSH config.";
        };
      };

      config = mkIf cfg.enable {
        services.openssh = {
          enable = true;

          settings = {
            PasswordAuthentication = false;
            # Upstream leaves this on, and with UsePAM it still accepts a
            # password.
            KbdInteractiveAuthentication = false;
            PermitRootLogin = "no";
            AllowUsers = [ config.dafos.user.name ];
          };

          extraConfig = ''
            StreamLocalBindUnlink yes
          '';

          ports = [
            22
            cfg.port
          ];
        };

        programs.ssh.extraConfig = ''
          Host *
            HostKeyAlgorithms +ssh-rsa

          Host github.com
            IdentityFile ~/.ssh/gh@captainspof.pem
            IdentitiesOnly yes

          ${optionalString cfg.manage-other-hosts other-hosts-config}
        '';

        dafos.user.extraOptions.openssh.authorizedKeys.keys = authorizedKeys;
      };
    };
}
