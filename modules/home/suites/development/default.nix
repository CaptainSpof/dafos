{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt enabled disabled;

  cfg = config.${namespace}.suites.development;
in
{
  options.${namespace}.suites.development = {
    enable = mkBoolOpt false "Whether or not to enable common development configuration.";
    aws.enable = mkBoolOpt false "Whether or not to enable aws development configuration.";
    postman.enable = mkBoolOpt false "Whether or not to enable postman configuration.";
    docker.enable = mkBoolOpt false "Whether or not to enable docker development configuration.";
    kubernetes.enable = mkBoolOpt false "Whether or not to enable kubernetes development configuration.";
    nix.enable = mkBoolOpt true "Whether or not to enable nix development configuration.";
    sql.enable = mkBoolOpt false "Whether or not to enable sql development configuration.";
  };

  config = mkIf cfg.enable {
    home = {
      packages =
        with pkgs;
        [
          jq
          jqp
          github-desktop
          tokei # need to know how many lines of poorly written code you typed ? 🦀
          wildcard
        ]
        ++ lib.optionals cfg.nix.enable [
          nixfmt
          nixpkgs-fmt
          nixpkgs-hammering
          nixpkgs-review
          nix-update
        ]
        ++ lib.optionals cfg.sql.enable [
          dbeaver-bin
          mysql-workbench
        ]
        ++ lib.optionals cfg.postman.enable [ postman ];

      # shellAliases = {
      #   prefetch-sri = "nix store prefetch-file $1";
      # };
    };

    dafos = {
      programs = {
        graphical = {
          editors = {
            emacs = enabled;
            vscode = disabled;
          };
        };

        terminal = {
          editors = {
            helix = enabled;
            neovim = enabled;
          };

          tools = {
            aws.enable = cfg.aws.enable;
            git-crypt = enabled;
            k9s.enable = cfg.kubernetes.enable;
            lazydocker.enable = cfg.docker.enable;
            lazygit = enabled;
            node = disabled;
            python = disabled;
            tealdeer = enabled;
          };
        };
      };
    };
  };
}
