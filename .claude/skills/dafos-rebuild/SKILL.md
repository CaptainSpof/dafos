---
name: dafos-rebuild
description: Build, verify, format and deploy a dafos change. Use when a Nix edit needs checking before switching, when asked whether a change evaluates or what it actually changes in the system closure, when deploying to a remote host, when a build fails and the error needs tracing, or before committing anything that touches modules, hosts or the flake.
---

# Rebuilding and verifying dafos

Verification comes before switching. A change that only needs to be proven
correct should never require a `switch`, and `dafoltop` in particular should not
be switched casually — see `systems/x86_64-linux/dafoltop/AGENTS.md`.

## 1. Format the files you touched — and only those

```bash
nix fmt path/to/changed.nix
```

**Never run `nix fmt` with no arguments.** Repo-wide formatting churns roughly
80 files, drowning the real diff, and has truncated files in the past. If
several files changed:

```bash
git diff --name-only --diff-filter=d | xargs -r nix fmt
```

The `.claude/hooks/format-changed-file.sh` PostToolUse hook already does this
per edit, so this step is usually a no-op — confirm with `git status` rather
than reformatting.

## 2. Evaluate

Fastest signal that a module change is well-formed, no build required:

```bash
nix eval --raw '.#nixosConfigurations.<host>.config.system.build.toplevel.drvPath'
```

To inspect what an option actually resolved to across the archetype/suite chain:

```bash
nix eval '.#nixosConfigurations.<host>.config.dafos.services.foo' --json | jq
nix eval '.#homeConfigurations."daf@<host>".config.dafos.programs.ai' --json | jq
```

## 3. Build

```bash
nix build '.#nixosConfigurations.<host>.config.system.build.toplevel'
```

Hosts: `dafbox`, `dafoltop`, `daftop`, `virt` (`x86_64-virtualbox`). Build the
host you changed. Build all of them only when the change is in a shared module
or in `lib/`.

Home Manager alone:

```bash
nix build '.#homeConfigurations."daf@<host>".activationPackage'
```

## 4. Prove it changed something

A green build does not mean the intended thing happened. Compare closures before
and after:

```bash
nix build '.#nixosConfigurations.<host>.config.system.build.toplevel' -o /tmp/after
nix store diff-closures /run/current-system /tmp/after
```

For a module refactor that is supposed to be a no-op, `nix-diff` between the two
`.drv` paths is the check that actually proves it:

```bash
nix-diff /tmp/before.drv /tmp/after.drv
```

Same derivation hash means the refactor changed nothing. This is the
verification method to reach for whenever a change is described as "pure
cleanup".

## 5. Apply

```bash
sudo nixos-rebuild switch --flake .#<host>          # local
nix run .#deploy -- .#<host>                        # remote, deploy-rs
```

`lib/deploy` switches to `doas -u` instead of sudo on hosts where
`dafos.security.doas.enable` is set. Deploying to `dafoltop` needs an
interactive sudo prompt; it will stall if run unattended.

Prefer `nixos-rebuild test` when the change is risky and a reboot would recover
it, and `nixos-rebuild build-vm` when the change touches boot or display
managers.

## When a build fails

1. Re-run with `--show-trace -L` and read the _first_ error, not the last.
2. `nix log <drv-or-out-path>` for the full builder output of a failed
   derivation.
3. `nix why-depends '.#nixosConfigurations.<host>.config.system.build.toplevel' <pkg>`
   to find what pulled a package in.
4. For "infinite recursion", suspect a module reading `config` from the same
   option it defines, or a gate on final-closure contents rather than on module
   state.

## Flake input bumps

```bash
cp flake.lock "flake.lock.$(date +%Y%m%d-%H%M%S).bak"
nix flake update <input>
```

Bump one input at a time when something breaks; build every host afterwards,
since inputs are shared. `.bak` lock files are gitignored.
