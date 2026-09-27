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

Scope follows the path:

- `secrets/dafoltop/*.yaml` — the self-hosted services. Admin, the dafoltop user
  and root keys, and the dafbox user key so they can be edited from the
  workstation. daftop (a laptop) and the other root keys are left out on
  purpose: losing one of them must not hand over the homelab.
- `secrets/daf/*.yaml` — what several hosts genuinely share (github, vicinae,
  rustdesk). Admin plus every user and root key.
- `secrets/daftop/daf/*.yaml` — admin plus the daftop user only.

A secret that a _system_ service must read has to be in a file the host root key
can open — see the OIDC entries in `secrets/dafoltop/`, which both a
home-manager stack and a NixOS service consume.

**The admin key is lost** (as of 2026-09-27; it is on no host). Every file must
therefore stay readable by at least one host or user key someone still holds;
never re-key a file down to admin alone.

## The age identity

With the admin key gone, the files everything derives from are each host's
`~/.ssh/daf@<host>.pem` (the user identity; the home sops module regenerates
`~/.config/sops/age/keys.txt` from it) and `/etc/ssh/ssh_host_ed25519_key` (the
root identity). Losing both on a host means its secrets stop decrypting.

Host SSH host keys derive the per-host root identity. Regenerating them on
reinstall breaks system secrets unless the old key is restored first, or
`.sops.yaml` is rekeyed with `ssh-to-age` followed by `sops updatekeys`.

## Workflow

Use the `dafos-secrets` skill (`.claude/skills/dafos-secrets`) for the add,
rotate and new-host procedures.
