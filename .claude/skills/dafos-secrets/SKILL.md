---
name: dafos-secrets
description: Add, edit, rotate or scope a sops-nix secret in dafos. Use when a service needs a password, token, API key or client secret; when a secret fails to decrypt or a unit cannot read /run/secrets; when onboarding a new host or reinstalling one; or when asked which key group a secret belongs to.
---

# Secrets in dafos

Encrypted YAML under `secrets/`, age keys and rules in `.sops.yaml`. Background
on the key groups is in `secrets/AGENTS.md`; this is the procedure.

**Never write plaintext under `secrets/`.** `.claude/settings.json` denies
writes there, and a pre-commit hook checks encryption — treat both as backstops,
not as the plan.

## Pick the file first

The path decides who can decrypt. From `.sops.yaml`:

| Path                             | Decryptable by                                         |
| -------------------------------- | ------------------------------------------------------ |
| `secrets/<name>.yaml`            | admin key only                                         |
| `secrets/daf/<name>.yaml`        | admin + all three user keys + all three host root keys |
| `secrets/daftop/daf/<name>.yaml` | admin + the daftop user key                            |

A secret consumed by a **NixOS** service must live somewhere the host root key
can open, so `secrets/daf/` in practice. A secret shared between a home-manager
stack and a NixOS service — the Authelia/Immich and Home Assistant OIDC client
secrets, for instance — must be readable by both the user key and the host key,
which again means `secrets/daf/`.

## Add or edit

```bash
sops secrets/daf/<name>.yaml
```

sops decrypts into `$EDITOR` and re-encrypts on save. It picks the key group
from the path, so creating the file in the right directory is the whole
configuration step.

Then declare it on the consuming side:

```nix
sops.secrets."<name>" = {
  sopsFile = lib.snowfall.fs.get-file "secrets/daf/<name>.yaml";
  # owner/mode only when the unit cannot use LoadCredential
};
```

Prefer systemd `LoadCredential` over pointing a service at `/run/secrets`
directly — it is what lets a unit keep `DynamicUser`:

```nix
serviceConfig = {
  LoadCredential = [ "ha-token:${config.sops.secrets."<name>".path}" ];
};
environment.HA_LONG_LIVED_TOKEN_FILE = "%d/ha-token";
```

`modules/nixos/services/everything-presence-zone-configurator` is the worked
example.

## Re-key after changing `.sops.yaml`

Adding or removing a key does not touch existing files. Run:

```bash
sops updatekeys secrets/daf/<name>.yaml
# or every file the rule covers
find secrets -name '*.yaml' -exec sops updatekeys -y {} +
```

## New or reinstalled host

The per-host root identity is derived from the host's SSH host key, so a
reinstall that regenerates `/etc/ssh/ssh_host_ed25519_key` breaks every system
secret on that host.

Either restore the old host key before first boot (the dafbox runbook documents
this), or:

```bash
ssh-keyscan -t ed25519 <host> | ssh-to-age          # public → age recipient
```

Add the recipient to `.sops.yaml` under the matching `&root_<host>` anchor, then
`sops updatekeys` every file whose rule includes it.

`~/.config/sops/age/keys.txt` is the admin identity. It is the single most
important file in this setup; without it and without a preserved host key,
nothing decrypts.

## Verify on the target

```bash
sudo systemctl show <unit> -p LoadCredential
sudo ls -l /run/secrets/
journalctl -u <unit> -b --no-pager | tail -40
```

A secret that decrypts at build time but not at runtime is almost always a
key-group mismatch: check which key the _host_ has, not which key you have.
