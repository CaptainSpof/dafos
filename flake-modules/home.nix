# Bridge from NixOS modules into the main user's home-manager profile:
# `dafos.home.{file,configFile,extraOptions}` are forwarded to
# home-manager.users.<dafos.user.name>.
{
  flake.modules.nixos.home =
    {
      options,
      config,
      lib,
      ...
    }:

    let
      inherit (lib) types mkAliasDefinitions mkOption;
    in
    {
      options.dafos.home = {
        file = mkOption {
          type = types.attrs;
          default = { };
          description = "A set of files to be managed by home-manager's `home.file`.";
        };
        configFile = mkOption {
          type = types.attrs;
          default = { };
          description = "A set of files to be managed by home-manager's `xdg.configFile`.";
        };
        extraOptions = mkOption {
          type = types.attrs;
          default = { };
          description = "Options to pass directly to home-manager.";
        };
      };

      config = {
        dafos.home.extraOptions = {
          home.stateVersion = config.system.stateVersion;
          home.file = mkAliasDefinitions options.dafos.home.file;
          xdg.enable = true;
          xdg.configFile = mkAliasDefinitions options.dafos.home.configFile;
        };

        home-manager = {
          # enables backing up existing files instead of erroring if conflicts exist
          backupFileExtension = "hm.old";

          useUserPackages = true;
          useGlobalPkgs = true;

          users.${config.dafos.user.name} = mkAliasDefinitions options.dafos.home.extraOptions;

          verbose = true;
        };
      };
    };
}
