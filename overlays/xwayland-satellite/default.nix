# Steam's dropdown menus (and any X11 popup that sets `override_redirect`)
# close the instant they open under xwayland-satellite 0.8.2: satellite focuses
# the popup itself, Steam sees its parent lose focus and dismisses the menu.
#   https://github.com/ValveSoftware/steam-for-linux/issues/13566
#   https://github.com/Supreeeme/xwayland-satellite/issues/468
#
# Fixed upstream by PR #494 (never focus override-redirect popups, send
# WM_TAKE_FOCUS when the client advertises it), merged to main as add27951 on
# 2026-09-09 — after the v0.8.2 tag (2026-07-22) that nixpkgs ships, so build
# that commit until a release carries it.
# Drop this once nixpkgs' xwayland-satellite is > 0.8.2 and includes #494.
_:

_final: prev:

let
  src = prev.fetchFromGitHub {
    owner = "Supreeeme";
    repo = "xwayland-satellite";
    rev = "add2795134593faafce60e404a0a75df68e9ee0c";
    hash = "sha256-0TxfMgqW0/BLD4M942c5DCKYrtPvzsPJwvdcco4LQUM=";
  };
in
{
  xwayland-satellite = prev.xwayland-satellite.overrideAttrs (_old: {
    version = "0.8.2-unstable-2026-09-09";
    inherit src;

    # Cargo.lock moved between v0.8.2 and this commit, so the vendor dir has to
    # be refetched rather than inherited from the nixpkgs derivation.
    cargoDeps = prev.rustPlatform.fetchCargoVendor {
      inherit src;
      hash = "sha256-s1gl9eR6Mt2QLrhfcowstPFjzwE/lz4PJhJzWYHoIHg=";
    };
  });
}
