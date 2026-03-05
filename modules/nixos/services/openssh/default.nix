{
  config,
  lib,
  host ? "",
  format ? "",
  inputs ? { },
  namespace,
  ...
}:

let
  inherit (lib) optionalString mkIf types;
  inherit (lib.${namespace}) mkOpt mkBoolOpt;
  inherit (config.${namespace}.user) authorizedKeys;

  cfg = config.${namespace}.services.openssh;

  # @TODO(jakehamilton): This is a hold-over from an earlier Snowfall Lib version which used
  # the specialArg `name` to provide the host name.
  name = host;

  other-hosts = lib.filterAttrs (
    key: host: key != name && (host.config.${namespace}.user.name or null) != null
  ) (inputs.self.nixosConfigurations or { });

  other-hosts-config = lib.concatMapStringsSep "\n" (
    name:
    let
      remote = other-hosts.${name};
      remote-user-name = remote.config.${namespace}.user.name;
    in
    ''
      Host ${name}
        IdentityFile ~/.ssh/daf@${host}.pem
        IdentitiesOnly yes
        ControlMaster auto
        ControlPath ~/.ssh/control-%r@%h:%p
        ControlPersist 10m
        User ${remote-user-name}
        ForwardAgent yes
        Port ${builtins.toString cfg.port}
    ''
  ) (builtins.attrNames other-hosts);
in
{
  options.${namespace}.services.openssh = with types; {
    enable = mkBoolOpt false "Whether or not to configure OpenSSH support.";
    port = mkOpt port 2222 "The port to listen on (in addition to 22).";
    manage-other-hosts =
      mkOpt bool true
        "Whether or not to add other host configurations to SSH config.";
  };

  config = mkIf cfg.enable {
    services.openssh = {
      enable = true;

      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = if format == "install-iso" then "yes" else "no";
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
}
