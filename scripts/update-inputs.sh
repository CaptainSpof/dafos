#!/usr/bin/env bash
#
# Update flake inputs one at a time, paced so GitHub does not rate-limit us.
#
# `nix flake update` (and `nh os switch -u`) refresh every input at once, which
# downloads a source tarball per changed node -- around a hundred of them in a
# burst for this flake. That reliably trips GitHub's per-IP anti-scraping limit
# on the archive endpoints (api.github.com/repos/.../tarball,
# codeload.github.com, raw.githubusercontent.com), which answers HTTP 429 for a
# while afterwards. The access token in ~/.config/nix/nix.conf does not help:
# that limit is per-IP, not per-token, and an authenticated tarball request gets
# the same 429.
#
# So: update inputs individually, pause between them, and back off when GitHub
# does push back. Because `nix flake update <input>` rewrites flake.lock as it
# goes, progress is kept even if a later input fails.
#
# Usage:
#   scripts/update-inputs.sh                  # every top-level input
#   scripts/update-inputs.sh nixpkgs niri     # only these
#   scripts/update-inputs.sh -n               # dry run: list what would run
#   scripts/update-inputs.sh -d 15 -r 8       # slower, more retries
#
# Options:
#   -d, --delay N     seconds to wait between inputs (default 5)
#   -r, --retries N   attempts per input before giving up (default 5)
#   -n, --dry-run     list the inputs, change nothing
#   -h, --help        this text

set -euo pipefail

delay=5
retries=5
dry_run=false
declare -a wanted=()

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

usage() {
    sed -n '3,28p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
    -d | --delay)
        delay="${2:?--delay needs a value}"
        shift 2
        ;;
    -r | --retries)
        retries="${2:?--retries needs a value}"
        shift 2
        ;;
    -n | --dry-run)
        dry_run=true
        shift
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    -*) die "unknown option: $1" ;;
    *)
        wanted+=("$1")
        shift
        ;;
    esac
done

command -v nix >/dev/null || die "nix not found in PATH"
command -v jq >/dev/null || die "jq not found in PATH (run inside 'nix develop')"

# Resolve the flake directory from this script's location, so it works from
# anywhere.
flake_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$flake_dir"
[[ -f flake.nix ]] || die "no flake.nix in $flake_dir"

# The registry lives on channels.nixos.org and is not needed here -- every input
# in this flake is an explicit URL. Skipping it removes a flaky network
# dependency that has its own outages.
nix_flags=(--no-use-registries --flake-registry "")

# Collect the top-level input names, unless the caller named some.
if [[ ${#wanted[@]} -eq 0 ]]; then
    mapfile -t wanted < <(
        nix flake metadata --json "${nix_flags[@]}" 2>/dev/null |
            jq -r '.locks.nodes[.locks.root].inputs | keys[]'
    )
fi
[[ ${#wanted[@]} -gt 0 ]] || die "could not determine any flake inputs"

if [[ $dry_run == true ]]; then
    printf 'would update %d input(s), %ss apart:\n' "${#wanted[@]}" "$delay"
    printf '  %s\n' "${wanted[@]}"
    exit 0
fi

# Keep a copy of the lock: an interrupted run leaves a half-updated lockfile,
# and it is nice to be able to diff or roll back.
backup="flake.lock.$(date +%Y%m%d-%H%M%S).bak"
cp flake.lock "$backup"
printf 'saved lockfile backup to %s\n\n' "$backup"

declare -a updated=() unchanged=() failed=()
log=$(mktemp)
trap 'rm -f "$log"' EXIT

total=${#wanted[@]}
n=0

for input in "${wanted[@]}"; do
    n=$((n + 1))
    printf '[%d/%d] %s ... ' "$n" "$total" "$input"

    before=$(sha256sum flake.lock | cut -d' ' -f1)
    backoff=30
    attempt=1
    ok=false

    while ((attempt <= retries)); do
        if nix flake update "$input" "${nix_flags[@]}" >"$log" 2>&1; then
            ok=true
            break
        fi

        # 429 means GitHub is throttling us; anything else is a real error and
        # retrying will not help.
        if ! grep -q '429\|Too Many Requests' "$log"; then
            break
        fi

        printf 'rate-limited, waiting %ss ... ' "$backoff"
        sleep "$backoff"
        backoff=$((backoff * 2))
        attempt=$((attempt + 1))
    done

    if [[ $ok == true ]]; then
        after=$(sha256sum flake.lock | cut -d' ' -f1)
        if [[ $before == "$after" ]]; then
            printf 'up to date\n'
            unchanged+=("$input")
        else
            printf 'updated\n'
            updated+=("$input")
        fi
    else
        printf 'FAILED\n'
        failed+=("$input")
        sed 's/^/    | /' "$log" | tail -5
    fi

    # Pace the next request, but do not idle after the final input.
    if ((n < total)); then
        sleep "$delay"
    fi
done

printf '\n--- summary ---\n'
printf 'updated:   %d\n' "${#updated[@]}"
[[ ${#updated[@]} -gt 0 ]] && printf '  %s\n' "${updated[@]}"
printf 'unchanged: %d\n' "${#unchanged[@]}"
printf 'failed:    %d\n' "${#failed[@]}"
if [[ ${#failed[@]} -gt 0 ]]; then
    printf '  %s\n' "${failed[@]}"
    printf '\nre-run just those once GitHub calms down:\n'
    printf '  scripts/update-inputs.sh %s\n' "${failed[*]}"
    exit 1
fi

printf '\nlockfile backup: %s\n' "$backup"
