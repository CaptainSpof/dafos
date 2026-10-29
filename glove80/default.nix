# Glove80 firmware: MoErgo's ZMK fork, built with its own pinned nixpkgs.
# `nix-build glove80` -> result/glove80.uf2 (both halves in one file).
let
  zmkSrc = builtins.fetchTarball {
    url = "https://github.com/moergo-sc/zmk/archive/refs/tags/v26.09.tar.gz";
    sha256 = "0y8jyzlxlw0kfkigzy4szz2gj2qi9lgb5i8bfsa52vn9sh4g0vvn";
  };
  firmware = import zmkSrc { };

  half =
    board:
    firmware.zmk.override {
      inherit board;
      keymap = ./glove80.keymap;
      kconfig = ./glove80.conf;
    };
in
# combine_uf2's result is also a functor; nix-build would call it, so name it.
firmware.combine_uf2 (half "glove80_lh") (half "glove80_rh") "glove80"
