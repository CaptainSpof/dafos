{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib)
    mkIf
    concatStringsSep
    attrNames
    filterAttrs
    ;
  inherit (lib.${namespace}) mkBoolOpt enabled;
  inherit (config.${namespace}.programs.terminal.shells) fish;

  cfg = config.${namespace}.programs.terminal.tools.direnv;

  # The flake's own devenv templates (templates/<name>), for completion.
  templates = attrNames (
    filterAttrs (_: type: type == "directory") (builtins.readDir (lib.snowfall.fs.get-file "templates"))
  );
in
{
  options.${namespace}.programs.terminal.tools.direnv = {
    enable = mkBoolOpt false "Whether or not to enable direnv.";
  };

  config = mkIf cfg.enable {
    programs.direnv = {
      enable = true;
      nix-direnv = enabled;
    };

    # Project shells: `devinit <template>` drops a devenv.nix/devenv.yaml/.envrc
    # into the current directory. See templates/AGENTS.md.
    home.packages = [ pkgs.devenv ];

    programs.fish = mkIf fish.enable {
      shellAbbrs = {
        da = "direnv allow";
      };

      # `self` is the registry entry for the dafos revision the host was last
      # switched to, so this works offline and never picks up unswitched edits.
      functions.devinit = {
        description = "Scaffold a devenv shell here from a dafos template";
        body = ''
          set -l template devenv
          set -q argv[1]; and set template $argv[1]

          nix flake init --template self#$template; or return

          # Appended, not templated: `nix flake init` refuses to overwrite a
          # file, and cargo/uv/pnpm have usually written a .gitignore already.
          for line in '.devenv*' .direnv devenv.local.nix devenv.local.yaml .pre-commit-config.yaml
              grep -qxF -- $line .gitignore 2>/dev/null; or echo $line >>.gitignore
          end

          direnv allow
        '';
      };
    };

    xdg.configFile."fish/completions/devinit.fish" = mkIf fish.enable {
      text = "complete -c devinit -f -a '${concatStringsSep " " templates}'\n";
    };
  };
}
