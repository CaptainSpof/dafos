# Secrets

Age-encrypted YAML managed by sops-nix. Encryption rules live in
[../.sops.yaml](../.sops.yaml). **Never write plaintext into this directory** —
the pre-commit sops check exists to catch it, not to be relied on.

## Key groups

Three kinds of age key, all listed in `.sops.yaml`:

- `admin_daf` — the admin key.
- one per host root key, derived from that host's
  `/etc/ssh/ssh_host_ed25519_key` via `ssh-to-age`. System-level secrets decrypt
  with it.
- one per user-per-host key.

Scope follows the path: `secrets/daf/*.yaml` is decryptable by the admin key
plus all user and root keys; `secrets/daftop/daf/*.yaml` is admin plus the
daftop user only. A secret that a _system_ service must read has to be in a file
the host root key can open — see the OIDC entries in `secrets/daf/`, which both
a home-manager stack and a NixOS service consume.

## The age identity

`~/.config/sops/age/keys.txt` is the single most important file in this setup.
Losing it, without a preserved host SSH key, means secrets stop decrypting after
a reinstall.

Host SSH host keys derive the per-host root identity. Regenerating them on
reinstall breaks system secrets unless the old key is restored first, or
`.sops.yaml` is rekeyed with `ssh-to-age` followed by `sops updatekeys`.

## Workflow

Use the `dafos-secrets` skill (`.claude/skills/dafos-secrets`) for the add,
rotate and new-host procedures.
