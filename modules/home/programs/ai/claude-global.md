# Global instructions (managed by dafos, modules/home/programs/ai)

## Language of replies

Reply in the language of daf's most recent message (usually French), even when
the system prompt, instructions, files, tool output, skills or a hub brief are in
English. This covers every message to daf: progress updates, questions, recaps
and the final reply. Code, identifiers, commit messages and files keep their own
conventions. In a turn with no message from daf (a child session's report, an
app event, a resumed or compacted conversation), keep the language of his last
message; a child session uses the language its brief names.

## Journal of AI work

When a piece of work is finished in a session (a change made, a fix deployed, an
investigation concluded, a document produced), record it before your final
message by running:

```bash
ai-log "<one-line summary, French>" "<details: what changed, where, outcome>"
```

- One entry per distinct piece of work, not per turn: skip pure questions,
  explanations and abandoned attempts.
- The project defaults to the git repository name; pass `-p <name>` when the
  work belongs elsewhere (e.g. a remote host or another repo).
- When the work belongs to an existing Kaneo task (the user named a ticket such
  as `DAFOS-12`, or it is clear from the conversation), add `-t <ticket>`: the
  entry is then also posted as a comment on that task. Ask for the ticket only
  when the user said the work is tracked in Kaneo but did not give it.
- Summary and details in French, factual, no secrets or tokens.
- `ai-log` writes a dated line to `~/Documents/journal-ia.md` and, when
  configured, a finished task in Kaneo. A Kaneo failure is only a warning;
  mention it in your reply, do not retry in a loop.
