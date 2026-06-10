{
  config,
  lib,
  namespace,
  ...
}:

let
  inherit (lib.${namespace}) mkBoolOpt mkOpt;

  cfg = config.${namespace}.security.sops;
in
{
  options.${namespace}.security.sops = with lib.types; {
    enable = mkBoolOpt false "Whether to enable sops.";
    defaultSopsFile = mkOpt path null "Default sops file.";
    # System-level secrets are decrypted with the host SSH key, whose derived
    # age identity is the `root_<host>` key authorized in .sops.yaml.
    sshKeyPaths = mkOpt (listOf path) [
      "/etc/ssh/ssh_host_ed25519_key"
    ] "SSH Key paths to use.";
  };

  config = lib.mkIf cfg.enable {
    sops = {
      inherit (cfg) defaultSopsFile;

      age = {
        inherit (cfg) sshKeyPaths;

        keyFile = "${config.users.users.${config.${namespace}.user.name}.home}/.config/sops/age/keys.txt";
      };
    };

    # Declare secrets where this module is enabled, e.g.:
    #   sops.secrets."my_secret".sopsFile =
    #     lib.snowfall.fs.get-file "secrets/daf/default.yaml";
  };
}
