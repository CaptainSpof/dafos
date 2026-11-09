# Child brief — template

Copy this into `start_session`'s `prompt`, fill every line, delete none. A line
that does not apply says `none`.

```markdown
You are a child session started by the dafos hub. Do the work here yourself;
do not delegate and do not invoke /dafos-hub.

Language: daf wrote this task in <French | English>. Write every message to
daf in that language, even though this brief is in English.

## Task
<one sentence: the change or the answer daf wants>

## Read first
- `AGENTS.md` (root), then every `AGENTS.md` down to: <path>
- Skill: <dafos-home-assistant | dafos-add-service | dafos-secrets | dafos-rebuild | none>
- Files: <exact paths the task starts from>

Do NOT load: <unrelated hosts, other services, the whole tree>

## Do
1. <step>
2. <step>

## Deliver
- <file(s) changed, or the answer written in your final message>
- A local commit on your branch. Never push, merge or switch `dafoltop`.
- Your commit stays on your worktree branch and is not in `~/.config/dafos`, so
  a switch or deploy from there does not include it. Never give daf a switch or
  deploy command as the next step: say the commit is on your branch and the hub
  brings it into main, then give the test daf should do after the switch.
- Never stage `flake.lock` unless the task is about it: nix commands rewrite it
  in a worktree.

## Check
<one concrete check: `nix eval …` / `nix build …` / an HA state read / daf
looks at X>. Quote its output in your final message.

## Record
`ai-log "<résumé en français>" "<détails>"` <-t TICKET | no ticket>
```
