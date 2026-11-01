# Journal of work done with an AI agent: one line per piece of work in a local
# Markdown file, mirrored as a finished task in Kaneo when an API key is set.
# With -t, the work also lands as a comment on that Kaneo task (KEY-12), so a
# project mixing personal and AI work keeps its whole history in one place.
#
#   ai-log [-p project] [-t ticket] "summary" ["details"]

journal="${AI_LOG_FILE:-$HOME/Documents/journal-ia.md}"
kaneo_env="${XDG_CONFIG_HOME:-$HOME/.config}/ai-log/kaneo.env"

usage() {
    echo 'usage: ai-log [-p project] [-t ticket] "summary" ["details"]' >&2
    exit 2
}

project=""
ticket=""
while getopts "p:t:h" opt; do
    case "$opt" in
    p) project="$OPTARG" ;;
    t) ticket="$OPTARG" ;;
    *) usage ;;
    esac
done
shift $((OPTIND - 1))

[ $# -ge 1 ] && [ -n "$1" ] || usage
summary="$1"
details="${2:-}"

if [ -z "$project" ]; then
    project="$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")"
fi

day="$(date +%F)"
time="$(date +%H:%M)"
host="$(hostname)"

# One line per entry, newest last; a bare file grows its header first.
if [ ! -s "$journal" ]; then
    mkdir -p "$(dirname "$journal")"
    printf '# Journal IA\n\n' >"$journal"
fi
line="- $day $time · **$project**"
[ -n "$ticket" ] && line="$line · $ticket"
line="$line · $summary"
[ -n "$details" ] && line="$line — $details"
printf '%s\n' "$line" >>"$journal"
echo "journal: $journal"

# Kaneo is best effort: the local line is the record of truth.
[ -r "$kaneo_env" ] || exit 0
# shellcheck disable=SC1090
. "$kaneo_env"
if [ -z "${KANEO_API_KEY:-}" ] || [ -z "${KANEO_PROJECT_ID:-}" ]; then
    echo "kaneo: KANEO_API_KEY or KANEO_PROJECT_ID missing in $kaneo_env, skipped" >&2
    exit 0
fi

api="${KANEO_API_URL:-https://kaneo-api.daftdaf.dev/api}"

# kaneo METHOD PATH [JSON]: the response body, or curl's error on stderr.
kaneo() {
    curl -fsS --max-time 15 -X "$1" \
        -H "Authorization: Bearer $KANEO_API_KEY" \
        -H "Content-Type: application/json" \
        ${3:+-d "$3"} "$api$2"
}

# Resolve the linked task first: its title goes into the journal entry.
linked_id=""
linked=""
if [ -n "$ticket" ]; then
    if task="$(kaneo GET "/task/by-ticket-id/$ticket" 2>&1)"; then
        linked_id="$(jq -r '.id' <<<"$task")"
        linked="$ticket — $(jq -r '.title' <<<"$task")"
    else
        echo "kaneo: ticket $ticket not found: $task" >&2
    fi
fi

description="$(printf '**Projet :** %s  \n**Date :** %s %s  \n**Machine :** %s' \
    "$project" "$day" "$time" "$host")"
[ -n "$linked" ] && description="$(printf '%s  \n**Tâche liée :** %s' "$description" "$linked")"
description="$(printf '%s\n\n%s\n' "$description" "$details")"
body="$(jq -n \
    --arg title "[$project] $summary" \
    --arg description "$description" \
    --arg status "${KANEO_STATUS:-done}" \
    --arg date "${day}T${time}:00" \
    '{title: $title, description: $description, priority: "no-priority",
    status: $status, startDate: $date, dueDate: $date}')"

entry=""
if response="$(kaneo POST "/task/$KANEO_PROJECT_ID" "$body" 2>&1)"; then
    number="$(jq -r '.number // empty' <<<"$response" 2>/dev/null || true)"
    # The journal ticket (IA-8) reads better than a bare number in the comment.
    if [ -n "$number" ] && [ -n "$linked_id" ] &&
        key="$(kaneo GET "/project/$KANEO_PROJECT_ID" 2>/dev/null | jq -r '.slug // empty')" && [ -n "$key" ]; then
        entry="$key-$number"
    fi
    echo "kaneo: task $(jq -r '.id // "created"' <<<"$response" 2>/dev/null || echo created)"
else
    echo "kaneo: task creation failed: $response" >&2
fi

[ -n "$linked_id" ] || exit 0
comment="$(printf '**IA · %s %s · %s** — %s' "$day" "$time" "$host" "$summary")"
[ -n "$details" ] && comment="$(printf '%s\n\n%s' "$comment" "$details")"
[ -n "$entry" ] && comment="$(printf '%s\n\n_Journal IA : %s_' "$comment" "$entry")"
if response="$(kaneo POST "/comment/$linked_id" "$(jq -n --arg c "$comment" '{content: $c}')" 2>&1)"; then
    echo "kaneo: comment on $ticket"
else
    echo "kaneo: comment on $ticket failed: $response" >&2
fi
