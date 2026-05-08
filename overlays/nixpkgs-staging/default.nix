{ channels, ... }:

_final: _prev:

{
    inherit (channels.nixpkgs-staging)
        calibre
    ;
}
