# immich-kiosk

Immich server v3 and later requires immich-kiosk **≥ 0.40**. v3 stopped
embedding `assets` in the album response, and older kiosk builds log "no assets
found" for every album instead of failing loudly. Bump both together.
