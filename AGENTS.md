# dafos

`dafos` is Cédric's (CaptainSpof) personal fleet of NixOS + Home Manager
configs, built with [Snowfall Lib](https://snowfall.org/guides/lib/quickstart/)
under the `dafos` namespace — options live at `dafos.*` (`dafos.services.foo`,
`dafos.suites.desktop`). Repo: `github.com/CaptainSpof/dafos`, cloned at
`~/.config/dafos`. Apache 2.0.

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

| Host       | System            | Role                                                                 | Desktop                           |
| ---------- | ----------------- | -------------------------------------------------------------------- | --------------------------------- |
| `dafbox`   | x86_64-linux      | Desktop/workstation                                                  | Niri (autologin) + DMS greeter    |
| `dafoltop` | x86_64-linux      | Laptop repurposed as homelab server — runs most self-hosted services | Plasma (autologin), Niri disabled |
| `daftop`   | x86_64-linux      | Laptop                                                               | Niri                              |
| `virt`     | x86_64-virtualbox | Throwaway VM                                                         | —                                 |

`dafoltop` is the de facto home server and the live house — see
[systems/x86_64-linux/dafoltop/AGENTS.md](systems/x86_64-linux/dafoltop/AGENTS.md)
before touching anything that runs on it.

## Layout and composition

Standard Snowfall layout: `systems/`, `homes/`, `modules/{nixos,home}/`,
`packages/`, `overlays/`, `lib/`, `secrets/`, `shells/`, `checks/`. Read the
tree rather than a description of it.

Configuration composes in one direction:

`archetypes` (workstation/gaming/server) → `suites` (common, desktop,
development, games, graphics, music, office, social, video, yahrr, common-slim)
→ `services`/`programs`/`apps`.

Host `default.nix` files mostly toggle suites and override specifics with
`lib.mkForce`. To find out what a host actually enables, follow the
archetype/suite chain — never just the host file.

## Workflow

```bash
nix fmt path/to/changed.nix                        # treefmt; changed paths only, never the repo
sudo nixos-rebuild switch --flake .#<host>         # local
nix run .#deploy -- .#<host>                       # remote (deploy-rs, via lib/deploy)
```

`direnv`/`use flake` is set up, so `nix develop` auto-activates here. Pre-commit
hooks (git-hooks.nix) run treefmt (non-blocking), clang-tidy, luacheck and a
sops-encryption check inside that shell.

Custom helpers live under `lib.dafos.*`: option builders (`mkOpt`, `mkOpt'`,
`mkBoolOpt`), the `enabled`/`disabled` shortcuts, audio node helpers,
`network.create-proxy`, `mkDeploy`. See [lib/AGENTS.md](lib/AGENTS.md).

## Scoped guidance

- [modules/AGENTS.md](modules/AGENTS.md) — module conventions, option ownership
- [systems/AGENTS.md](systems/AGENTS.md) — host configuration and validation
- [lib/AGENTS.md](lib/AGENTS.md) — custom library namespaces
- [packages/AGENTS.md](packages/AGENTS.md) — local package discovery and
  vendoring
- [secrets/AGENTS.md](secrets/AGENTS.md) — sops-nix key groups and secret
  workflow
- [modules/home/services/AGENTS.md](modules/home/services/AGENTS.md) —
  self-hosted service stack

Deeper `AGENTS.md` files cover individual hosts and modules; the directory you
are editing owns its own rules.
