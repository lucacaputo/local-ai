#!/usr/bin/env bash
# Launches Claude Code against the local router from macOS (counterpart of scripts\claude-local.ps1).
# The key is read from the Keychain and exists only in the claude process environment.
# ANTHROPIC_API_KEY / ANTHROPIC_AUTH_TOKEN are removed for the child: either one would replace
# the subscription login and switch Claude requests to API billing.
# Router URL: $LOCAL_AI_ROUTER, else ~/.config/local-ai/router-url (written by setup-client.sh).
# All arguments are passed to claude unchanged.
set -euo pipefail

repo="$(cd "$(dirname "$0")/../.." && pwd)"
conf="${XDG_CONFIG_HOME:-$HOME/.config}/local-ai"
router="${LOCAL_AI_ROUTER:-}"
[[ -z "$router" && -r "$conf/router-url" ]] && router="$(<"$conf/router-url")"
if [[ -z "$router" ]]; then
  echo "No router URL. Run scripts/mac/setup-client.sh first." >&2
  exit 1
fi
key="$(security find-generic-password -a "$USER" -s local-ai/router-key -w 2>/dev/null)" || {
  echo "No router key in the Keychain. Run scripts/mac/setup-client.sh first." >&2
  exit 1
}

exec env -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN \
  ANTHROPIC_BASE_URL="$router" \
  ANTHROPIC_CUSTOM_HEADERS="x-litellm-api-key: Bearer $key" \
  claude --settings "$repo/config/claude-settings.json" "$@"
