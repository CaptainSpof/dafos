# Home Assistant module

Declarative half of the live Home Assistant on dafoltop. Read
[systems/x86_64-linux/dafoltop/AGENTS.md](../../../../systems/x86_64-linux/dafoltop/AGENTS.md)
before changing anything here, and use the `dafos-home-assistant` skill for the
API, the UI-side automations and deploying.

## Language: an exception to the repo rule

The repo writes code, comments and docs in English. This module makes **one
exception**: text that Home Assistant itself shows is written in **French**.

| French                                                          | English                                                  |
| --------------------------------------------------------------- | -------------------------------------------------------- |
| automation/script `description`, script `fields.*.description`  | Nix `#` comments, this file, commit messages             |
| step `alias` (inside `actions`, `choose`, `if`, `conditions`…)  | automation/script top-level `alias` (`<Area> · <Thing>`) |
| entity display names (`name` of helpers and template entities)  | `id`, entity ids, `unique_id`, `default_entity_id`       |
| notification titles, messages, action labels, TTS, Divoom texts | variables, keys, MQTT topics, notification `tag`s        |

The same split applies to the UI automations and scripts edited through the API.

- Do not rename an entity whose id still derives from its name. Platform sensors
  (`history_stats`, `statistics`, `derivative`, `command_line`) take no
  `default_entity_id`, so their `name` stays English even though it is shown.
- Some `name`s feed templates (heating rooms reach the boiler-boost
  notification, printer tanks reach the ink notification). Check where a name
  flows before you translate it.
- Notification `tag`s are matched by auto-clear rules. Never translate them.
