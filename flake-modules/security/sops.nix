{
  flake.modules.nixos.sops =
    {
      config,
      lib,
      ...
    }:

    let
      inherit (lib) mkOption types;

      cfg = config.dafos.security.sops;
    in
    {
      options.dafos.security.sops = {
        enable = lib.mkEnableOption "sops";
        defaultSopsFile = mkOption {
          type = types.path;
          default = null;
          description = "Default sops file.";
        };
        # System-level secrets are decrypted with the host SSH key, whose derived
        # age identity is the `root_<host>` key authorized in .sops.yaml.
        sshKeyPaths = mkOption {
          type = types.listOf types.path;
          default = [ "/etc/ssh/ssh_host_ed25519_key" ];
          description = "SSH Key paths to use.";
        };
      };

      config = lib.mkIf cfg.enable {
        sops = {
          inherit (cfg) defaultSopsFile;

          age = {
            inherit (cfg) sshKeyPaths;

            keyFile = "${config.users.users.${config.dafos.user.name}.home}/.config/sops/age/keys.txt";
          };
        };

        # Declare secrets where this module is enabled, e.g.:
        #   sops.secrets."my_secret".sopsFile = inputs.self + "/secrets/daf/default.yaml";
      };
    };
}
