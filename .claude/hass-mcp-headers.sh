#!/usr/bin/env bash
# headersHelper for the home-assistant MCP server in ../.mcp.json: prints the
# Authorization header as JSON on each connection. The token is decrypted from
# sops (needs daf's age key) and never written to disk.
set -euo pipefail
cd "$(dirname "$0")/.."
token=$(sops -d --extract '["ha-admin-token"]' secrets/dafoltop/home-assistant.yaml)
jq -cn --arg t "$token" '{Authorization: ("Bearer " + $t)}'
