# nixpkgs bumped libdisplay-info to 0.4.0, but the `libdisplay-info-sys` crate
# vendored by both pinned niri revisions is 0.3.0, whose build script asks
# pkg-config for `libdisplay-info < 0.4.0` and hard-fails otherwise. nixpkgs
# keeps a `libdisplay-info_0_3` compat attribute for exactly this (its own
# `niri` package uses it), so point niri-flake's packages at it too.
# Drop this once niri-unstable ships a Cargo.lock with libdisplay-info-sys 0.4.
_:

_final: prev:

let
  useOldDisplayInfo =
    package:
    package.override {
      libdisplay-info = prev.libdisplay-info_0_3;
    };
in
{
  niri-stable = useOldDisplayInfo prev.niri-stable;
  niri-unstable = useOldDisplayInfo prev.niri-unstable;
}
