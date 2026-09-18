{ pkgs, ... }:

{
  languages.python = {
    enable = true;
    # A specific interpreter needs the nixpkgs-python input:
    #   devenv inputs add nixpkgs-python github:cachix/nixpkgs-python --follows nixpkgs
    # version = "3.13";

    # `.devenv/state/venv`, activated on shell entry.
    venv.enable = true;
    uv = {
      enable = true;
      # Once pyproject.toml exists, keep the venv synced to uv.lock on entry.
      # sync.enable = true;
    };
  };

  packages = [ pkgs.ruff ];
}
