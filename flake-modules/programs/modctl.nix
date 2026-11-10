# modctl (~/Projects/modctl, flake input): the one mod-manager executable.
# `modctl status|check` (updates against the collection / Nexus, or any folder
# of archives), `modctl nxm` (downloads), `modctl update` (download checklist),
# `modctl install|uninstall` (locally or to the Steam Deck over SSH). Config
# and locks live in ~/Games/mods/<game>/, never in Nix.
#
# Registered as the x-scheme-handler/nxm handler: a Nexus "Mod manager
# download" button lands the file in that game's `archives` folder (else
# ~/Downloads/mods/<domain>) with no browser dialog, using the personal API
# key in ~/.config/nexus-apikey (never logged or printed). Takes over from
# nexusmods-app, which registers itself too. Log: ~/.local/state/modctl/nxm.log
{ inputs, ... }:
{
  flake.modules.homeManager.modctl =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.dafos.programs.modctl;
      modctl = inputs.modctl.packages.${pkgs.stdenv.hostPlatform.system}.modctl;
    in
    {
      # shortcut: old name kept while daf@dafbox still sets it; drop once it
      # says programs.modctl.
      imports = [
        (lib.mkRenamedOptionModule [ "dafos" "programs" "nxm-handler" ] [ "dafos" "programs" "modctl" ])
      ];

      options.dafos.programs.modctl.enable =
        lib.mkEnableOption "modctl, the Nexus Mods manager and nxm:// handler";

      config = lib.mkIf cfg.enable {
        home.packages = [ modctl ];

        xdg.desktopEntries.modctl-nxm = {
          name = "Nexus Mods downloader";
          exec = "${lib.getExe modctl} nxm %u";
          mimeType = [ "x-scheme-handler/nxm" ];
          noDisplay = true;
          terminal = false;
        };

        xdg.mimeApps = {
          enable = true;
          defaultApplications."x-scheme-handler/nxm" = lib.mkForce [ "modctl-nxm.desktop" ];
          associations.added."x-scheme-handler/nxm" = lib.mkForce [ "modctl-nxm.desktop" ];
        };
      };
    };
}
