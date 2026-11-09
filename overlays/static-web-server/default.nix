# nixpkgs now forces common sys crates onto system libraries (NixOS/nixpkgs#537108),
# so zstd-sys panics in static-web-server's build without pkg-config. Backport of
# NixOS/nixpkgs#585189; drop this once nixos-unstable contains it. An overlay
# because services.static-web-server has no package option; only dafoltop uses it.
_:

_final: prev:

{
  static-web-server = prev.static-web-server.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.pkg-config ];
    buildInputs =
      (old.buildInputs or [ ])
      ++ (with prev; [
        zstd
        libgit2
      ]);
  });
}
