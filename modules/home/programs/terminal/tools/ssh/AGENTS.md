# ssh (client)

## Steam Deck (`ssh dafdeck`, alias `deck`)

Host `dafdeck`, user `deck`, key `~/.ssh/daf@dafbox.pem`, reached by its
Tailscale MagicDNS name (LAN fallback: `192.168.0.30`, DHCP lease on the
Freebox). Not a Nix host: SteamOS, configured by hand.

- sshd on the Deck: key-only, `AllowUsers` limited to the LAN and the tailnet
  (`/etc/ssh/sshd_config.d/50-dafos.conf`). Both the drop-in and the Tailscale
  files are listed under `/etc/atomic-update.conf.d/` so SteamOS updates keep
  them. After a major update, check `ssh dafdeck` still works. Re-run
  `deck-tailscale`'s `tailscale.sh` if `/opt/tailscale` went missing.
- Free to do: anything under `/home/deck` and on the SD card (mods, tools,
  Flatpak `--user`, scripts).
- Outside `/home` is wiped by SteamOS updates, apart from the files listed in
  `/etc/atomic-update.conf.d/`. Do not install system packages (read-only root).
- `sudo` needs daf's password: never type, ask for or store it. Hand him the
  command to run in his own session.
- The Deck suspends and drops SSH; ask daf to wake it, or disable sleep while
  working.

## From an agent session

Inside a Claude session the `~/.ssh/config` symlink target in `/nix/store` shows
as owned by `nobody` (user namespace), so OpenSSH refuses it: "Bad owner or
permissions", exit 255. It is not a real permission problem; do not "fix" it
here. Bypass the file:
`ssh -F /dev/null -o IdentitiesOnly=yes -i ~/.ssh/daf@dafbox.pem deck@dafdeck`.
Tools that call plain `ssh dafdeck` (modctl) fail the same way from a session.
