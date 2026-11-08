#!/usr/bin/env bash
# Launches OpenCode against the local router from macOS, for the local models (counterpart of
# scripts\opencode-local.ps1, TASK-038; Claude models stay in claude-local.sh).
# No key: tailscale serve tells the router which Tailscale login is calling, and the router lets in
# the allowlisted ones (TASK-023, TASK-024). OpenCode sends LOCAL_AI_ROUTER_KEY as its bearer token,
# so it gets the same fixed, non-secret marker as claude-local.sh.
# config/opencode.json names the models, their windows and effort, and the permissions.
# Router URL: $LOCAL_AI_ROUTER, else ~/.config/local-ai/router-url (written by setup-client.sh).
# All arguments are passed to opencode unchanged (--auto approves what the config would ask for).
set -euo pipefail

repo="$(cd "$(dirname "$0")/../.." && pwd)"
conf="${XDG_CONFIG_HOME:-$HOME/.config}/local-ai"
router="${LOCAL_AI_ROUTER:-}"
[[ -z "$router" && -r "$conf/router-url" ]] && router="$(<"$conf/router-url")"
if [[ -z "$router" ]]; then
  echo "No router URL. Run scripts/mac/setup-client.sh first." >&2
  exit 1
fi
if ! command -v opencode >/dev/null; then
  echo "OpenCode is not installed: npm install -g opencode-ai@1.19.3 (the pin in scripts/versions.psd1)." >&2
  exit 1
fi

exec env OPENCODE_CONFIG="$repo/config/opencode.json" \
  LOCAL_AI_ROUTER_URL="$router" \
  LOCAL_AI_ROUTER_KEY="tailscale-identity" \
  opencode "$@"
