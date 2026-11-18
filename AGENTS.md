# dafos

`dafos` is Cédric's (CaptainSpof) personal fleet of NixOS + Home Manager
configs. Options live at `dafos.*` (`dafos.services.foo`,
`dafos.suites.desktop`). Repo: `github.com/CaptainSpof/dafos`, cloned at
`~/.config/dafos`. Apache 2.0.

The flake is built with [flake-parts](https://flake.parts) + import-tree (the
dendritic pattern) and is mid-migration from
[Snowfall Lib](https://snowfall.org/guides/lib/quickstart/): a compat layer
still evaluates the Snowfall-shaped trees. See
[flake-modules/AGENTS.md](flake-modules/AGENTS.md).

User is `daf` / Cédric Da Fonseca, uid 1000, shell fish, single-user boxes.

## Instruction ownership

Guidance lives in the `AGENTS.md` closest to the code it describes; the closest
one wins. Before editing a subtree, read every `AGENTS.md` from this file down
to the target path.

`CLAUDE.md` files are one-line `@AGENTS.md` imports so the same guidance serves
any agent. Put provider-neutral rules in `AGENTS.md`, never in the importer.

**This file never grows a gotchas list.** A newly discovered gotcha belongs next
to the module or host it describes. Longer rationale goes in that directory's
`README.md`, with a one-line rule plus a pointer in its `AGENTS.md`.

## The fleet

| Host       | System        | Role                                                                 | Desktop                           |
| ---------- | ------------- | -------------------------------------------------------------------- | --------------------------------- |
| `dafbox`   | x86_64-linux  | Desktop/workstation                                                  | Niri (autologin) + DMS greeter    |
| `dafoltop` | x86_64-linux  | Laptop repurposed as homelab server — runs most self-hosted services | Plasma (autologin), Niri disabled |
| `daftop`   | x86_64-linux  | Laptop                                                               | Niri                              |
| `dafpi`    | aarch64-linux | Orange Pi 5, small always-on server taking load off dafoltop         | none                              |
| `dafrelay` | aarch64-linux | Raspberry Pi 4, off-site backup target at a family member's home     | none                              |

`dafoltop` is the de facto home server and the live house — see
[systems/x86_64-linux/dafoltop/AGENTS.md](systems/x86_64-linux/dafoltop/AGENTS.md)
before touching anything that runs on it.

## Layout and composition

`flake-modules/` holds the dendritic aspects and hosts (dafpi and dafrelay are
built only from it). The rest is the legacy Snowfall layout: `systems/`,
`homes/`, `modules/{nixos,home}/`, `packages/`, `overlays/`, `lib/`, `secrets/`,
`shells/`, `checks/`. Read the tree rather than a description of it.

Configuration composes archetypes → suites → services/programs/apps, so a host
file alone never tells what a host enables: see
[modules/AGENTS.md](modules/AGENTS.md), "Composition".

## Workflow

```bash
nix fmt path/to/changed.nix                        # treefmt; changed paths only, never the repo
sudo nixos-rebuild switch --flake .#<host>         # local
deploy -s .#<host> --interactive-sudo true         # remote (deploy-rs CLI; -s: checks.pre-commit-hooks is broken)
```

**Switching and deploying are daf's to run.** Agents have no sudo on the fleet:
build and check the change (`dafos-rebuild` skill), then hand daf the exact
command above. Without `--interactive-sudo true`, sudo cannot prompt and
deploy-rs rolls back.

**Never push without the user's explicit go for that push.** Committing locally
is fine; `git push` (any branch, any remote) waits until the user says to push
those commits. An earlier "push" does not cover later commits.

`direnv`/`use flake` is set up, so `nix develop` auto-activates here. Pre-commit
hooks (git-hooks.nix) run treefmt (non-blocking), clang-tidy, luacheck and a
sops-encryption check inside that shell.

## Scoped guidance

- [flake-modules/AGENTS.md](flake-modules/AGENTS.md) — dendritic aspects, hosts
  and the Snowfall compat layer
- [modules/AGENTS.md](modules/AGENTS.md) — module conventions, option ownership
- [systems/AGENTS.md](systems/AGENTS.md) — host configuration and validation
- [homes/AGENTS.md](homes/AGENTS.md) — per-host Home Manager config (suites,
  service toggles, DMS layout)
- [lib/AGENTS.md](lib/AGENTS.md) — `lib.dafos.*` helpers (`mkOpt`, `enabled`,
  `mkDeploy`)
- [packages/AGENTS.md](packages/AGENTS.md) — local package discovery and
  vendoring
- [secrets/AGENTS.md](secrets/AGENTS.md) — sops-nix key groups and secret
  workflow
- [templates/AGENTS.md](templates/AGENTS.md) — devenv project templates
  (`devinit`)
- [esphome/AGENTS.md](esphome/AGENTS.md) — DIY ESPHome device firmware (build,
  first flash, board quirks)
- [glove80/AGENTS.md](glove80/AGENTS.md) — Glove80 ZMK keymap mirroring the
  kanata config (build, flash)
- [flake-modules/services/AGENTS.md](flake-modules/services/AGENTS.md) — service
  aspects, where new services go
- [modules/home/services/AGENTS.md](modules/home/services/AGENTS.md) —
  self-hosted service stack (nps, OIDC, storage)
- [modules/home/stacks/AGENTS.md](modules/home/stacks/AGENTS.md) — local nps
  stacks (Renovate pins, `vm-test.nix`)

Deeper `AGENTS.md` files cover individual hosts and modules; the directory you
are editing owns its own rules.
