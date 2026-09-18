{ pkgs, ... }:

{
  languages.rust = {
    enable = true;
    # Default is nixpkgs' stable toolchain (rustc, cargo, clippy, rustfmt,
    # rust-analyzer). Other channels or targets go through rust-overlay:
    #   devenv inputs add rust-overlay github:oxalica/rust-overlay --follows nixpkgs
    # channel = "nightly";
    # targets = [ "wasm32-unknown-unknown" ];
  };

  packages = [ pkgs.cargo-watch ];
}
