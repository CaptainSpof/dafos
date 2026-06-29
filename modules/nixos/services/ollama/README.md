# Local LLM for Home Assistant notifications (dafoltop)

Replaces the ChatGPT-based notification message generation with a local model
served by Ollama on dafoltop itself (so Home Assistant talks to it over
localhost).

## What the Nix config already does

- `dafos.services.ollama` runs `ollama-cpu` on `127.0.0.1:11434` and pulls
  `qwen2.5:3b` on boot (`services.ollama.loadModels`).
- `OLLAMA_KEEP_ALIVE=5m` unloads the model after idle so it doesn't sit on
  ~3 GB of RAM next to Home Assistant + Immich.
- The `ollama` integration is added to Home Assistant's components.

Enabled in `systems/x86_64-linux/dafoltop` via `services.ollama = enabled;`.

Apply with your usual rebuild (e.g. `nh os switch`). First boot will download
the model (~2 GB) — check progress with `journalctl -u ollama-model-loader -f`.

## One-time UI step (config-flow integration)

The Ollama integration is set up through the UI, not YAML:

1. Settings → Devices & Services → Add Integration → **Ollama**.
2. URL: `http://127.0.0.1:11434`. Model: `qwen2.5:3b`.
3. This creates an **AI Task** entity, e.g. `ai_task.ollama` (exact entity id
   shown on the integration page).

## Replace the ChatGPT automation

Wherever the old automation called the OpenAI conversation, swap in
`ai_task.generate_data` and feed the result to your existing `notify` action.
Example (adapt the trigger / prompt / notify target to your current one):

```yaml
- alias: "LLM notification"
  triggers:
    # ... your existing trigger (e.g. a state change) ...
  actions:
    - action: ai_task.generate_data
      data:
        task_name: "notification_message"
        entity_id: ai_task.ollama          # from the integration page
        instructions: >
          Write a short, friendly French notification (one sentence, no emoji)
          telling the household that {{ trigger.to_state.name }} is now
          {{ trigger.to_state.state }}.
      response_variable: result
    - action: notify.notify              # your existing notify target
      data:
        message: "{{ result.data }}"
```

Notes:
- `qwen2.5:3b` is multilingual and handles short French/English strings well.
- First request after idle reloads the model (a few seconds on the i7-8550U);
  subsequent ones within `OLLAMA_KEEP_ALIVE` are quick. Bump `keepAlive` (or set
  `"-1"` to pin) if you want it always warm, at the cost of held RAM.
- To swap models later, edit `dafos.services.ollama.models` and rebuild.
```
