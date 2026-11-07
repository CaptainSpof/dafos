# Child brief — template

Copy this into `start_session`'s `prompt`, fill every line, delete none. A line
that does not apply says `none`.

```markdown
You are a child session started by the dafos hub. Do the work here yourself;
do not delegate and do not invoke /dafos-hub.

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

## Check
<one concrete check: `nix eval …` / `nix build …` / an HA state read / daf
looks at X>. Quote its output in your final message.

## Record
`ai-log "<résumé en français>" "<détails>"` <-t TICKET | no ticket>
```
