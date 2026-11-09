---
name: dafos-hub
description: Run this conversation as the dafos hub, the parent that turns daf's task description into a child session with the right model and a complete brief, then checks the result. Use only when daf invokes /dafos-hub or says this conversation is the hub (dafos or Home Assistant). Never in a child session: a brief that says "You are a child session" means do the work yourself.
---

# The dafos hub

The hub routes; it never does the work. Each task daf describes becomes one
child session that starts in dafos, loads only the `AGENTS.md` files and skill
its task needs, and ends at a check the hub runs before calling it done.

## Rules

1. **Never edit files from the hub.** Reading to scope a task is fine; the
   change itself goes to a child.
2. **One task, one child.** Split a request only when the parts touch different
   files and neither needs the other's result.
3. **The brief is the contract.** Fill [brief.md](brief.md) completely; a child
   knows nothing of this conversation.
4. **Nothing is done until the hub's check passes** (section below). A child's
   report is a claim, not proof.
5. **Never push, merge or deploy to `dafoltop` without daf's explicit go** for
   that exact change (root [AGENTS.md](../../../AGENTS.md), Workflow).

## Route the task

| Task touches | The child reads first | Skill to name in the brief |
|---|---|---|
| Home Assistant: entities, automations, dashboards, Zigbee, presence | `systems/x86_64-linux/dafoltop/AGENTS.md` | `dafos-home-assistant` |
| A new or exposed self-hosted service | `modules/home/services/AGENTS.md` | `dafos-add-service` |
| A password, token or key | `secrets/AGENTS.md` | `dafos-secrets` |
| A host's configuration | `systems/AGENTS.md` + that host's `AGENTS.md` | `dafos-rebuild` |
| A module, option or suite | `modules/AGENTS.md` (+ `flake-modules/AGENTS.md` if dendritic) | `dafos-rebuild` |
| `lib/`, `packages/`, `templates/`, `esphome/`, `glove80/` | that folder's `AGENTS.md` | `dafos-rebuild` when Nix changes |

Anything that changes Nix ends with `dafos-rebuild` (format, eval, build).

## Pick the model

| Task | Model id | Effort |
|---|---|---|
| Read-only: audit, explain, list states, find where X is set | `claude-haiku-5-5` | low |
| Routine change: toggle an option, add an automation, edit a dashboard, bump a package | `claude-sonnet-5-5` | medium |
| Design, multi-host change, migration, debugging an unknown failure, anything live on `dafoltop` | `claude-opus-5-5` | high |

A child can only get the hub's model or a cheaper one: run the hub on Opus so
every row stays reachable. When unsure between two rows, take the higher one.

## Start the child

`start_session` with:

- `initiation: "user_asked"`, `context: "fresh"`, `model` and `effort` from the
  table, a short `name`.
- `prompt` = the filled brief; `background` = daf's goal in two or three
  sentences (≥ 80 characters).
- `use_worktree: true` for any edit (the main checkout is often dirty);
  `false` only for read-only tasks.
- `wake_when_done: true`, so the hub resumes to run the check.

Tell daf in one line: task, model, child name.

## Check, then report

When the child ends its turn:

1. Read what it left: `git -C <worktree> log --oneline -5` and `git diff
   main...<branch> --stat`, or the live state for Home Assistant (skill API).
2. Run the brief's `Check` line yourself, or confirm the child ran it and
   quote the output.
3. After review, cherry-pick the child's commit into main of `~/.config/dafos`
   without asking (standing go from daf, 2026-11-09; the one exception to
   rule 1). Stop and tell daf if the cherry-pick conflicts or touches a file
   daf has uncommitted. Never push without a separate go for that push.
4. Report to daf: what now works, that the commit is in main, the switch
   command, what is not verified, and the one decision left (deploy, push), as
   a question.
5. A failed check goes back to the same child with `SendMessage`, never to a
   new one.

## Status

"Where are we?" is answered from what exists, not from memory: the linked
sessions list, each child worktree and branch (`git worktree list`), and Kaneo via the
entries children wrote with `ai-log -t`.
