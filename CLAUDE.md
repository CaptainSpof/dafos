# dafos — reference for Claude

`dafos` is Cédric's (CaptainSpof) personal fleet of NixOS + Home Manager configs, built with
[Snowfall Lib](https://snowfall.org/guides/lib/quickstart/) under the `dafos` namespace
(options live at `dafos.*`, e.g. `dafos.services.foo`, `dafos.suites.desktop`). Repo:
`github.com/CaptainSpof/dafos`, cloned at `~/.config/dafos`. License Apache 2.0.

This file is project-scoped instructions/context for Claude. Standard Snowfall layout
(`systems/`, `homes/`, `modules/{nixos,home}/`, `packages/`, `overlays/`, `lib/`, `secrets/`,
`shells/`, `checks/`) — read the tree directly rather than relying on a description here, since
it drifts. What follows is context that isn't obvious from a single file read.

## The fleet

| Host | System | Role | Desktop | Notes |
|---|---|---|---|---|
| `dafbox` | x86_64-linux | Desktop/workstation | Niri (autologin) + DMS greeter | AMD CPU+GPU (Navi 31/RX 7900), gaming archetype, sunshine, syncthing |
| `dafoltop` | x86_64-linux | Laptop repurposed as **homelab server** | Plasma (autologin), Niri disabled | Runs most self-hosted services (see below); sleep/suspend/hibernate disabled; journald capped at 500M; nh keeps only 5 generations/7d |
| `daftop` | x86_64-linux | Laptop | Niri | sudo-rs enabled, gaming archetype, Firefox Nightly (vs. beta on dafbox) |
| `virt` | x86_64-virtualbox | Throwaway VM | — | disposable test target |

User is `daf` / Cédric Da Fonseca, uid 1000, shell fish, single-user boxes (uid never needs to
differ). Per-host authorized SSH keys and per-host sops key are declared in
`modules/nixos/user/default.nix` and `.sops.yaml`.

`dafoltop` is the de facto home server: home-assistant, ollama (local LLM), immich + immich-kiosk,
authelia, bar-assistant, traefik, lldap, glance, calibre, donetick, grimmory, it-tools, norish,
papra, reactive-resume, shelfmark, streaming. It replaced ChatGPT-based HA notification
generation with a local ollama model (`qwen2.5:3b` via `ollama-cpu`, `127.0.0.1:11434`,
`OLLAMA_KEEP_ALIVE=5m`) — see `modules/nixos/services/ollama/README.md` for the one-time HA UI
integration step (config-flow, not YAML) and the `ai_task.generate_data` automation pattern
that replaced the OpenAI conversation call.

## Secrets (sops-nix)

Age-encrypted YAML under `secrets/`, rules in `.sops.yaml`. Key groups: one admin key
(`admin_daf`), one per-host root key (derived from each host's SSH host key via `ssh-to-age`),
one per-user-per-host key. `secrets/daf/*.yaml` is decryptable by admin + all three user keys +
all three root keys; `secrets/daftop/daf/*.yaml` is scoped tighter (admin + daftop user only).

**The age identity at `~/.config/sops/age/keys.txt` is the single most important file in this
setup** — losing it (without a preserved host SSH key) means secrets stop decrypting after a
reinstall. Host SSH host keys (`/etc/ssh/ssh_host_ed25519_key`) derive the per-host root age
identity used to decrypt system secrets; regenerating them on reinstall breaks system secrets
unless the old key is restored first (see dafbox runbook below) or `.sops.yaml` is rekeyed with
`ssh-to-age` + `sops updatekeys`.

## Known gotchas / non-obvious pins

- **claude-desktop flake input tracks upstream `main`** (`github:aaddrick/claude-desktop-debian`,
  no rev pin) — the earlier pin to rev `e85450c` (worked around a `.asar --add-dir` build failure
  against a later rev) has been lifted; don't assume it's still pinned.
- `pnpm-10.29.2` is in `permittedInsecurePackages` — required after a vicinae bump pulled it in.
- **Root-podman container DNS**: the NixOS firewall silently drops container→aardvark-dns
  traffic on custom podman networks (symptom inside the container: `dial tcp: lookup <host> on
  10.89.x.1:53: i/o timeout`). Fixed fleet-wide in the podman module by opening port 53 on
  `podman+` interfaces. Rootless containers are unaffected (their networking lives in a user
  namespace). Also: Immich server ≥ v3 requires immich-kiosk ≥ 0.40 (v3 stopped embedding
  `assets` in the album response; older kiosks log "no assets found" for every album).
- **OIDC for native NixOS services**: Authelia (and lldap) are nps stacks in daf's *home-manager*
  config, so services that run as NixOS services can't be wired up by `nps.stacks.<name>.oidc`.
  Home Assistant and Immich are registered by hand instead: the client, claims/authorization
  policies and lldap groups live in `modules/home/services/{authelia,lldap}`, the app-side config
  lives in `modules/nixos/services/<name>`, and both halves read the same `secrets/daf/*.yaml`
  entry (decryptable by the user *and* host key). For Immich the module mirrors what
  `nps.stacks.immich.oidc` would generate (custom `immich` scope, `immich_role`/`immich_quota`
  claims, `immich_{admin,user}` groups); its client secret reaches immich through
  `settings.oauth.clientSecret._secret`, i.e. systemd `LoadCredential`, never the nix store.
- **dafbox audio**: the Navi 31 GPU exposes multiple HDMI/DP audio profiles but only one active
  at a time; WirePlumber defaults to the higher-priority M27Q port, which has no speakers (only
  the LG monitor does). Fixed declaratively via a `wireplumber.extraConfig` ALSA rule in
  `systems/x86_64-linux/dafbox/default.nix` pinning `output:hdmi-stereo-extra1`. Full detail in
  memory `dafos-audio`.
- **dafbox fan control**: `dafos.hardware.sensors` only turns on CoolerControl; it does *not* give
  it anything to control. The board's NCT6799D Super-I/O (which owns CPU_FAN/CHA_FAN/AIO_PUMP) has
  no driver unless `nct6775` is in `boot.kernelModules` — coolercontrold detects the chip and then
  logs `status: skipped_no_modprobe`, leaving the GPU's `pwm1` as the only writable PWM on the box
  and the CPU curve stuck in BIOS Q-Fan. Loaded explicitly in `dafbox/hardware.nix`; no
  `acpi_enforce_resources=lax` needed despite ACPI reserving `io 0x0290-0x029f`. On this board
  **CPU_FAN is `fan2`/`pwm2`**, not `fan1`; `fan6`/`fan7` sit at 82% with no tach (unpopulated pump
  headers), and asus-ec-sensors' `Water_In`/`Water_Out` are phantom readings — dafbox is air-cooled.
  The ASUS EC does not fight manual `pwm2_enable=1`, so no BIOS change is required. Curves live in
  `/var/lib/coolercontrol` and are *stateful* — `programs.coolercontrol.enable` is the only NixOS
  option, so only the driver half is declarative.
- **gamescope from Steam launch options on Niri**: needs `env MESA_VK_WSI_PRESENT_MODE=mailbox
  gamescope <flags> -- env -u MESA_VK_WSI_PRESENT_MODE gamemoderun %command%` — without it,
  gamescope's first present to its output window deadlocks in Mesa's Wayland FIFO WSI (game runs
  with sound, no window; Plasma unaffected). Never use `-e` as a per-game wrapper. gamescope +
  gamemode are baked into Steam's FHS sandbox via `extraPkgs`/`extraLibraries` in the steam
  module; the sandbox has a private `/tmp` (debug probes must write to `$HOME`). Full detail in
  memory `dafos-gamescope`.
- **Theming/light-dark on Niri**: the KDE Settings xdg-desktop-portal backend can't recompute
  light/dark outside a full Plasma session under Niri and always reports "light". Fixed by
  routing just `org.freedesktop.impl.portal.Settings` to the `gtk` backend and having DMS own
  light/dark directly instead of following the portal's appearance signal
  (`modules/home/desktop/{dms,niri}/default.nix`). Full chain in memory `dafos-theming`.
- `dafoltop` disables sleep/suspend/hibernate targets and documentation generation (it's
  headless-ish homelab); don't assume these are fleet-wide defaults when editing shared modules.
- Firefox package differs per host on purpose: dafbox/daftop use `firefox-beta`, daftop was
  switched to `inputs.firefox` nightly — check the specific host file before assuming which
  channel is live.
- **DMS "Games" folder** (`dafos.desktop.dms.gamesFolder`, on wherever `suites.games` is): DMS
  has no notion of a folder in the app drawer, so this is faked with two halves that must agree
  on what a game is — `dms-games-sync` (a user service + path unit on
  `~/.local/share/applications`) classifies desktop entries, writes `~/.local/state/dms-games/
  games.json`, and pushes those ids into DMS's `session.json` `hiddenApps`; the `gamesFolder`
  launcher plugin (`modules/home/desktop/dms/plugins/games`) reads that JSON back. The rule
  lives only in the script. Hiding an app also removes it from DMS's built-in *Games* category
  chip (both go through `getVisibleApplications`), which is why the plugin enumerates
  `DesktopEntries` rather than reusing that filter, and why `NoDisplay=true` is the wrong lever
  (quickshell drops NoDisplay entries from `DesktopEntries.applications` entirely). Plugin
  enable-state is seeded once into the runtime-owned `plugin_settings.json`; turning the option
  off runs `dms-games-sync --unhide` from activation to put the games back.

## dafbox disk layout — applied (2026-06)

dafbox now runs the declarative disko btrfs layout described in
`systems/x86_64-linux/dafbox/DISK-POOL-PLAN.md` and `DISK-DESTRUCTIVE-RUNBOOK.md`: ESP + 36G
swap (hibernate-capable, >30GiB RAM) + 100G btrfs `/` on the Sabrent NVMe, and a `/home` btrfs
pool (`data=single`, `metadata=raid1`) spanning the rest of the Sabrent + the whole 970 EVO
(~1.2TB total, no data redundancy — either drive dying loses `/home`, hence "mandatory backups"
language in the runbook). `disko.nix` is imported from `dafbox/default.nix`, and `hardware.nix`
no longer hand-declares `/`, `/home`, `/boot`, or swap — disko generates those. The two `.md`
docs remain as reference for the rationale and the exact commands/host-key-preservation steps
used, useful if the layout is ever revisited or another host needs the same treatment.

## Workflow conventions

- Formatting: `nix fmt` (treefmt-nix; see `treefmt.nix` for the full formatter list — nixfmt,
  biome, ruff, rustfmt, shfmt, stylua, statix, deadnix, yamlfmt, etc.). Pre-commit hooks
  (git-hooks.nix) run treefmt (non-blocking, `fail-on-change = false`), clang-tidy, luacheck,
  and a sops-encryption check automatically inside `nix develop`.
- Rebuild locally: `sudo nixos-rebuild switch --flake .#<host>`. Remote: `nix run .#deploy --
  .#<host>` (deploy-rs, wired via `lib.mkDeploy` in `lib/deploy/default.nix`, respects
  `dafos.security.doas.enable` → uses `doas -u` instead of sudo when set).
- `direnv`/`use flake` is set up (`.envrc`) — a `nix develop` shell auto-activates in this dir.
- Custom `lib.dafos.*` helpers: `mkOpt`/`mkOpt'`/`mkBoolOpt` (option builders), `enabled`/
  `disabled` shortcuts (`{ enable = true/false; }`), audio helpers (`mkAlsaRename`,
  `mkAudioNode`, `mkVirtualAudioNode`, `mkBridgeAudioModule` in `lib/audio`), `network.create-proxy`
  / `network.get-address-parts` for nginx reverse proxies, `mkDeploy` for deploy-rs wiring.
- Composition pattern: `archetypes` (workstation/gaming/server) turn on bundles of `suites`;
  `suites` (common, desktop, development, games, graphics, music, office, social, video, yahrr,
  common-slim) turn on bundles of `services`/`programs`/`apps`. Per-host `default.nix` files
  mostly toggle suites/services/apps and override specifics with `lib.mkForce` — check the
  archetype/suite chain, not just the host file, to see what's actually enabled.
- `yahrr` suite = the *arr/torrent stack grouping (currently mostly commented out/disabled in
  favor of dafoltop's actual homelab service set — don't assume it's active).

## Related memory

- `dafos-audio` — LG monitor vs M27Q speaker routing detail (dafbox).
- `dafos-theming` — full NixOS+Niri light/dark chain (DMS → matugen → kdeglobals + xdg portal).
