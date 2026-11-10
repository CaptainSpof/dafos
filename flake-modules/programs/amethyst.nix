# Amethyst Mod Manager (ChrisDKN/Amethyst-Mod-Manager, nixpkgs
# amethyst-mod-manager): native Linux mod manager, Cyberpunk 2077 among ~100
# supported games. Chosen on 2026-11-10 over the Nexus Mods App (discontinued,
# no Cyberpunk collection import) and Limo (no Cyberpunk game profile).
#
# Mod update checks use the Nexus API key (stored in the OS keyring by the app,
# free account is enough); archives downloaded by hand are imported from the
# UI. The nixpkgs build ships with the app self-update banner disabled.
#
# nxm:// stays with `modctl nxm` (flake-modules/programs/modctl.nix: downloads
# with the personal API key into the game's archives, no manager running).
# Amethyst can register itself as an nxm handler from its settings: don't, or
# it takes the scheme over.
_: {
  flake.modules.homeManager.amethyst =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.dafos.programs.amethyst;
    in
    {
      options.dafos.programs.amethyst = {
        enable = lib.mkEnableOption "Amethyst Mod Manager";
        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.dafos.amethyst-mod-manager;
          description = "Amethyst Mod Manager package (vendored under packages/, nixpkgs lacks it at the locked revision).";
        };
      };

      config = lib.mkIf cfg.enable {
        home.packages = [ cfg.package ];
      };
    };
}
