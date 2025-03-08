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
    sshKeyPaths = mkOpt (listOf path) [
      "${config.home.homeDirectory}/.ssh/daf@dafoltop.pem"
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

    sops.secrets = {
      "daftop_daf_ssh_key" = {
        sopsFile = lib.snowfall.fs.get-file "secrets/dafos/daf/default.yaml";
      };
    };
  };
}
