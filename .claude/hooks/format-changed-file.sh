#!/usr/bin/env bash
# Format only the file Claude just wrote.
#
# Repo-wide `nix fmt` churns ~80 files (and has truncated them before), so the
# rule "format changed paths only" is enforced here rather than left to memory.
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

file=$(jq -r '.tool_input.file_path // empty')
[ -n "$file" ] || exit 0
[ -f "$file" ] || exit 0

# Stay inside the repository; never format anything Claude touched elsewhere.
root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
case "$file" in
"$root"/*) ;;
*) exit 0 ;;
esac

case "$file" in
*.nix | *.py | *.rs | *.sh | *.lua | *.json | *.yaml | *.yml | *.toml | *.md)
    nix fmt "$file" >/dev/null 2>&1
    ;;
esac

exit 0
