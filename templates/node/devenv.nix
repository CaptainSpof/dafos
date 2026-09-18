_:

{
  languages.javascript = {
    enable = true;
    # package = pkgs.nodejs_24;
    pnpm.enable = true;
    # Run `pnpm install` on shell entry once package.json exists.
    # pnpm.install.enable = true;
  };

  # languages.typescript.enable = true;
}
