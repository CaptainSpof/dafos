# Journal of work done with an AI agent: one line per piece of work in a local
# Markdown file, mirrored as a finished task in Kaneo when an API key is set.
#
#   ai-log [-p project] "summary" ["details"]

journal="${AI_LOG_FILE:-$HOME/Documents/journal-ia.md}"
kaneo_env="${XDG_CONFIG_HOME:-$HOME/.config}/ai-log/kaneo.env"

usage() {
    echo 'usage: ai-log [-p project] "summary" ["details"]' >&2
    exit 2
}

project=""
while getopts "p:h" opt; do
    case "$opt" in
    p) project="$OPTARG" ;;
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
line="- $day $time · **$project** · $summary"
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
description="$(printf '**Projet :** %s  \n**Date :** %s %s  \n**Machine :** %s\n\n%s\n' \
    "$project" "$day" "$time" "$host" "$details")"
body="$(jq -n \
    --arg title "[$project] $summary" \
    --arg description "$description" \
    --arg status "${KANEO_STATUS:-done}" \
    --arg date "${day}T${time}:00" \
    '{title: $title, description: $description, priority: "no-priority",
    status: $status, startDate: $date, dueDate: $date}')"

if response="$(curl -fsS --max-time 15 -X POST \
    -H "Authorization: Bearer $KANEO_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$body" "$api/task/$KANEO_PROJECT_ID" 2>&1)"; then
    echo "kaneo: task $(jq -r '.id // "created"' <<<"$response" 2>/dev/null || echo created)"
else
    echo "kaneo: task creation failed: $response" >&2
fi
