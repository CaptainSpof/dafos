{
  projectRootFile = "flake.nix";

  programs = {
    actionlint.enable = true;
    biome = {
      enable = true;
      settings.formatter.formatWithErrors = true;
    };
    clang-format.enable = true;
    deadnix = {
      enable = true;
    };
    deno = {
      enable = true;
      # Using biome for these
      excludes = [
        "*.ts"
        "*.js"
        "*.json"
        "*.jsonc"
      ];
    };
    fantomas.enable = true;
    fish_indent.enable = true;
    gofmt.enable = true;
    isort.enable = true;
    nixfmt.enable = true;
    ruff-check.enable = true;
    ruff-format.enable = true;
    rustfmt.enable = true;
    shfmt = {
      enable = true;
      indent_size = 4;
    };
    statix.enable = true;
    stylua.enable = true;
    taplo.enable = true;
    yamlfmt.enable = true;
  };

  settings = {
    global.excludes = [
      "*.conf"
      "*.editorconfig"
      "*.envrc"
      "*.gif"
      "*.git-blame-ignore-revs"
      "*.gitattributes"
      "*.gitconfig"
      "*.gitignore"
      "*.ico"
      "*.kdl"
      "*.luacheckrc"
      "*.png"
      "*.rasi"
      "*.svg"
      "*.xml"
      "*.zsh"
      "*CODEOWNERS"
      "*LICENSE"
      "*Makefile"
      "*flake.lock"
      "*makefile"
    ];

    formatter.ruff-format.options = [ "--isolated" ];
  };
}
