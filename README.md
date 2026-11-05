# dafos

> "It ain't pretty, but it's mine."

<a href="https://nixos.wiki/wiki/Flakes" target="_blank">
	<img alt="Nix Flakes Ready" src="https://img.shields.io/static/v1?logo=nixos&logoColor=d8dee9&label=Nix%20Flakes&labelColor=5e81ac&message=Ready&color=d8dee9&style=for-the-badge">
</a>
<a href="https://flake.parts" target="_blank">
	<img alt="Built With flake-parts" src="https://img.shields.io/static/v1?logoColor=d8dee9&label=Built%20With&labelColor=5e81ac&message=flake-parts&color=d8dee9&style=for-the-badge">
</a>
<a href="https://github.com/CaptainSpof/dafos/blob/main/LICENSE" target="_blank">
	<img alt="License: Apache 2.0" src="https://img.shields.io/static/v1?label=License&labelColor=5e81ac&message=Apache%202.0&color=d8dee9&style=for-the-badge">
</a>

> [!WARNING]
> 🏗 We be Wiping — this repo is in active flux. Modules move, hosts come and go,
> expect rough edges.

## About

**dafos** is my personal fleet of NixOS and Home Manager configurations.
Everything is declarative, managed via Nix Flakes and built with
[flake-parts](https://flake.parts) +
[import-tree](https://github.com/vic/import-tree) (the
[dendritic pattern](https://github.com/mightyiam/dendritic)). It is
mid-migration away from [Snowfall Lib](https://github.com/snowfallorg/lib): a
compat layer still evaluates the legacy Snowfall-shaped trees.

## Features

- **Declarative & modular.** Each feature is one dendritic aspect under
  `flake-modules/`, with its NixOS and Home Manager sides in one file.
- **Desktops, plural.** [Niri](https://github.com/YaLTeR/niri) (via
  [`niri-flake`](https://github.com/sodiboo/niri-flake)), KDE Plasma (via
  [`plasma-manager`](https://github.com/nix-community/plasma-manager)), and the
  [Dank Material Shell](https://github.com/AvengeMedia/DankMaterialShell).
- **Secrets.** Provisioned with [`sops-nix`](https://github.com/Mic92/sops-nix),
  age-encrypted at rest.
- **One formatter to rule them all.**
  [`treefmt-nix`](https://github.com/numtide/treefmt-nix) wires up nixfmt,
  biome, ruff, rustfmt, shfmt, stylua, statix, deadnix, and friends.
- **Gaming.** [`nix-gaming`](https://github.com/fufexan/nix-gaming) platform
  optimizations.
- **Multi-arch deploys.** `x86_64-linux` and `aarch64-linux` — pushed remotely
  with [`deploy-rs`](https://github.com/serokell/deploy-rs).
- **Custom bits.** Overlays (niri, Ryubing fixes), in-repo packages (Home
  Assistant cards, KDE theming, wallpapers, scripts), and project templates.

## Hosts

| Hostname       | System          | Role                             |
| :------------- | :-------------- | :------------------------------- |
| **`dafbox`**   | `x86_64-linux`  | Desktop / workstation            |
| **`dafoltop`** | `x86_64-linux`  | Laptop turned home server        |
| **`daftop`**   | `x86_64-linux`  | Laptop                           |
| **`dafpi`**    | `aarch64-linux` | Orange Pi 5, small server        |
| **`dafrelay`** | `aarch64-linux` | Raspberry Pi 4, off-site backups |

## Layout

- `flake-modules/` — dendritic aspects (`flake.modules.{nixos,homeManager}.*`),
  the pure hosts (dafpi, dafrelay) and the Snowfall compat layer. See
  [flake-modules/README.md](flake-modules/README.md).

The rest is the legacy
[Snowfall Lib](https://snowfall.org/guides/lib/quickstart/) layout, shrinking as
modules migrate:

- `systems/` — legacy NixOS host configurations (dafbox, dafoltop, daftop),
  partitioned by system architecture.
- `homes/` — Home Manager configs, named `user@host`.
- `modules/` — Reusable modules, split into `nixos/` and `home/`.
- `packages/` — In-tree Nix packages.
- `overlays/` — nixpkgs overlays.
- `lib/` — Custom helper functions exposed under the `dafos` namespace.
- `secrets/` — SOPS-encrypted YAML.
- `shells/` — `nix develop` environments (default + Rust).
- `templates/` — `nix flake init -t` project templates.
- `checks/` — Flake checks, incl. pre-commit hooks.

## Getting Started

### Prerequisites

- Nix with flakes enabled (`experimental-features = nix-command flakes`).
- Git.

### Clone & build locally

```bash
git clone https://github.com/CaptainSpof/dafos.git ~/.config/dafos
cd ~/.config/dafos

# Build a host (swap dafbox for the target hostname)
sudo nixos-rebuild switch --flake .#dafbox
```

### Remote deployment

Hosts wired up for [`deploy-rs`](https://github.com/serokell/deploy-rs) can be
pushed from anywhere:

```bash
deploy -s .#daftop --interactive-sudo true
```

### Dev shell

The repo ships a `nix develop` shell with the tools needed to work on it
(formatters, sops, deploy-rs, etc.):

```bash
nix develop
```

## Secrets

Secrets live under `secrets/` as SOPS-encrypted YAML, with rules in
`.sops.yaml`. With your age / GPG key set up:

```bash
sops secrets/daf/github.yaml
```

## Formatting

Everything is formatted through `treefmt-nix` (see [treefmt.nix](treefmt.nix)
for the full list of enabled formatters):

```bash
nix fmt path/to/changed.nix   # changed paths only, never the whole repo
```

Pre-commit hooks are wired up via
[`git-hooks.nix`](https://github.com/cachix/git-hooks.nix) — they run
automatically inside the dev shell.

## License

[Apache License 2.0](LICENSE).
