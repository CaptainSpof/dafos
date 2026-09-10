# Local packages

Snowfall discovers every `packages/<name>/default.nix` automatically and exposes
it as `packages.<system>.<name>` and in the overlay, so a new package needs no
registration.

## When to vendor

Package upstream here when it ships only as a container image or an add-on and
the fleet needs it as a plain service or derivation. Two rules learned from
[everything-presence-zone-configurator](everything-presence-zone-configurator):

- Mirror the upstream Dockerfile's build stage rather than inventing one, so
  upstream bumps stay mechanical.
- Check what the program resolves relative to its working directory. That one
  finds device profiles and its version string relative to `$PWD`, so the
  wrapper passes `--chdir`; the matching NixOS module lives in
  [../modules/nixos/services/everything-presence-zone-configurator](../modules/nixos/services/everything-presence-zone-configurator).

Home Assistant frontend cards (`lovelace-*`, `bubble-card`,
`custom-brand-icons`) are plain derivations copying built assets into `$out`;
follow the existing ones.
