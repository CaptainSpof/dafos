# dafos

> "It ain't pretty, but it's mine."

<a href="https://nixos.wiki/wiki/Flakes" target="_blank">
	<img alt="Nix Flakes Ready" src="https://img.shields.io/static/v1?logo=nixos&logoColor=d8dee9&label=Nix%20Flakes&labelColor=5e81ac&message=Ready&color=d8dee9&style=for-the-badge">
</a>
<a href="https://github.com/snowfallorg/lib" target="_blank">
	<img alt="Built With Snowfall" src="https://img.shields.io/static/v1?logoColor=d8dee9&label=Built%20With&labelColor=5e81ac&message=Snowfall&color=d8dee9&style=for-the-badge">
</a>
<a href="https://github.com/CaptainSpof/dafos/blob/main/LICENSE" target="_blank">
	<img alt="License: Apache 2.0" src="https://img.shields.io/static/v1?label=License&labelColor=5e81ac&message=Apache%202.0&color=d8dee9&style=for-the-badge">
</a>

> [!WARNING]
> 🏗 We be Wiping — this repo is in active flux. Modules move, hosts come and go, expect rough edges.

## About

**dafos** ("Here lies my shipwrecks. I mean fleet of hosts.") is my personal fleet of NixOS and Home Manager configurations. Everything is declarative, managed via Nix Flakes, and laid out using [Snowfall Lib](https://github.com/snowfallorg/lib) so hosts, users, modules, packages, and overlays each live where you'd expect.

## Features

- **Declarative & modular.** Snowfall Lib enforces a clean split between hosts, users, modules, packages, and overlays.
- **Desktops, plural.** [Niri](https://github.com/YaLTeR/niri) (via [`niri-flake`](https://github.com/sodiboo/niri-flake)), KDE Plasma (via [`plasma-manager`](https://github.com/nix-community/plasma-manager)), and the [Dank Material Shell](https://github.com/AvengeMedia/DankMaterialShell).
- **Secrets.** Provisioned with [`sops-nix`](https://github.com/Mic92/sops-nix), age-encrypted at rest.
- **One formatter to rule them all.** [`treefmt-nix`](https://github.com/numtide/treefmt-nix) wires up nixfmt, biome, ruff, rustfmt, shfmt, stylua, statix, deadnix, and friends.
- **Gaming.** [`nix-gaming`](https://github.com/fufexan/nix-gaming) platform optimizations.
- **Multi-arch deploys.** `x86_64-linux`, `aarch64-linux`, and a VirtualBox target — pushed remotely with [`deploy-rs`](https://github.com/serokell/deploy-rs).
- **Custom bits.** Overlays (Firefox addons, Zen Browser, KDE/GNOME tweaks), in-repo packages (Home Assistant cards, KDE theming, wallpapers, scripts), and project templates.

## Hosts

| Hostname       | System              | Role                        |
| :------------- | :------------------ | :-------------------------- |
| **`dafbox`**   | `x86_64-linux`      | Desktop / workstation       |
| **`dafoltop`** | `x86_64-linux`      | Laptop                      |
| **`daftop`**   | `x86_64-linux`      | Laptop                      |
| **`virt`**     | `x86_64-virtualbox` | Throwaway VM                |

## Layout

Standard [Snowfall Lib](https://snowfall.org/guides/lib/quickstart/) tree:

- `systems/` — NixOS host configurations, partitioned by system architecture.
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

Hosts wired up for [`deploy-rs`](https://github.com/serokell/deploy-rs) can be pushed from anywhere:

```bash
nix run .#deploy -- .#daftop
```

### Dev shell

The repo ships a `nix develop` shell with the tools needed to work on it (formatters, sops, deploy-rs, etc.):

```bash
nix develop
```

## Secrets

Secrets live under `secrets/` as SOPS-encrypted YAML, with rules in `.sops.yaml`. With your age / GPG key set up:

```bash
sops secrets/daf/default.yaml
```

## Formatting

Everything is formatted through `treefmt-nix` (see [treefmt.nix](treefmt.nix) for the full list of enabled formatters):

```bash
nix fmt
```

Pre-commit hooks are wired up via [`git-hooks.nix`](https://github.com/cachix/git-hooks.nix) — they run automatically inside the dev shell.

## License

[Apache License 2.0](LICENSE).
