# immich-kiosk

Immich server v3 and later requires immich-kiosk **≥ 0.40**. v3 stopped
embedding `assets` in the album response, and older kiosk builds log "no assets
found" for every album instead of failing loudly. Bump both together.

kiosk validates `config.yaml` strictly and exits on an unknown key
(`FATAL Invalid configuration`). 0.44 moved `show_more_info*` and
`*_button_action` under `more_info`, and 0.44 also needs Immich **≥ 3.2**. The
real config lives in
[../../services/immich-kiosk/settings.nix](../../services/immich-kiosk/settings.nix),
which `vm-test.nix` boots with, so a renamed key fails CI instead of dafoltop.
Read the release notes before merging a kiosk bump.
