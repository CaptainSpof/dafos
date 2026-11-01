# Global instructions (managed by dafos, modules/home/programs/ai)

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
- Summary and details in French, factual, no secrets or tokens.
- `ai-log` writes a dated line to `~/Documents/journal-ia.md` and, when
  configured, a finished task in Kaneo. A Kaneo failure is only a warning;
  mention it in your reply, do not retry in a loop.
