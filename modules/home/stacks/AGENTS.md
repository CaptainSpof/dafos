# Local nps stacks

Stacks that nix-podman-stacks does not ship, written in its own style
(`nps.stacks.<name>`, `mkAliases`, inline container images) so they could be
upstreamed as-is. Each one has a dafos wrapper in
[../services](../services/AGENTS.md) that adds sops secrets, `/mnt` paths and
subdomains. A stack module never touches sops or `dafos.*`, which is what lets
it boot in a bare test VM.

## Image pins: Renovate owns them

- Pin as an inline literal, `image = "registry/repo:tag";`. Renovate's regex
  manager (`renovate.json`) only sees that exact shape. An image that sits
  behind an option default is invisible to it.
- Put a `# renovate: versioning=semver` comment on the line **directly above**
  `image`; any line in between breaks the match.
- Minor and patch bumps of images at 1.0 or later automerge once CI is green.
  Majors and 0.x versions wait for review. Database and search images (postgres,
  pgvector, redis, meilisearch) are excluded: bump those by hand alongside a
  migration.

## Every stack ships a `vm-test.nix`

`<name>/vm-test.nix` boots the stack in a NixOS VM, through
[tests/integration/vm.nix](../../../tests/integration/vm.nix), which reuses
nps's upstream harness. It passes once every container reaches
`active (running)` and then goes 60 s without restarting. Keep it minimal:
`imports = [ ./default.nix ]`, `enable = true`, and secrets from the
`dummySecretFile` / `dummySecret` / `dummyHash` module args. Leave OIDC off
unless the test imports authelia. If the app refuses to start without some
setting (immich-kiosk wants an API key), give it a dummy value; don't boot its
backend.

```bash
nix build .#integrationTests.x86_64-linux.<name>-integration --no-link --option sandbox false -L
```

The sandbox has to be off because the VM pulls images, which is also why these
tests are not in `checks`. CI (`.github/workflows/integration.yml`) runs the
stacks a PR touches, or all of them when `flake.lock` or the harness changes.
Snowfall only imports `default.nix`, so a `vm-test.nix` never reaches a real
home.
