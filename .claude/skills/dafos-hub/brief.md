# Child brief — template

Copy this into `start_session`'s `prompt`, fill every line, delete none. A line
that does not apply says `none`.

```markdown
You are a child session started by the dafos hub. Do the work here yourself; do
not delegate and do not invoke /dafos-hub.

Language: daf wrote this task in <French | English>. Write every message to daf
in that language, even though this brief is in English.

## Task

<one sentence: the change or the answer daf wants>

## Read first

- `AGENTS.md` (root), then every `AGENTS.md` down to: <path>
- Skill: <dafos-home-assistant | dafos-add-service | dafos-secrets |
  dafos-rebuild | none>
- Files: <exact paths the task starts from>

Do NOT load: <unrelated hosts, other services, the whole tree>

## Do

1. First, build on daf's lock:
   `cp ~/.config/dafos/flake.lock flake.lock && git
   update-index --skip-worktree flake.lock`.
   Main often builds only with daf's uncommitted lock, so without this a build
   fails on stale hashes (DMS, dankcalendar).
2. <step>
3. <step>

## Deliver

- <file(s) changed, or the answer written in your final message>
- A local commit on your branch. Never push or switch `dafoltop`; the only merge
  allowed is the cherry-pick below.
- Once your check passes, cherry-pick your commit(s) into daf's main checkout
  yourself (standing go from daf, 2026-11-16):
  `git -C ~/.config/dafos cherry-pick <sha>...`, then verify it is identical:
  `git -C ~/.config/dafos diff HEAD~1 HEAD | diff - <(git show <sha> --format=)`
  (empty output). Never cherry-pick a commit that touches `flake.lock` or a file
  daf has uncommitted there (`git -C ~/.config/dafos status --short`); treat
  that like a conflict. If an index.lock error shows, another session is
  picking: wait a few seconds and retry once.
- On a conflict: `git -C ~/.config/dafos cherry-pick --abort` at once (never
  leave main mid-pick), then end with `wrap_up`, asking "Résoudre le conflit de
  <sha> dans main ?" with a "Résoudre" button first. On daf's yes, rebase your
  branch onto local `main`, resolve, re-run the check, and cherry-pick again.
- Then give daf the switch or deploy command and the test to do after it.
- `flake.lock` stays `skip-worktree` and is never committed, unless the task is
  about the lock itself (then `--no-skip-worktree` first).

## Check

<one concrete check: `nix eval …` / `nix build …` / an HA state read / daf looks
at X>. Quote its output in your final message.

## Record

`ai-log "<résumé en français>" "<détails>"` <-t TICKET | no ticket>
```
