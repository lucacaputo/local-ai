#!/usr/bin/env bash
# One-time setup of the local-ai router client on macOS. The Mac authenticates with its Tailscale
# identity (TASK-023, TASK-024), so no key is stored: this saves the router URL in
# ~/.config/local-ai/router-url, removes a router key left in the Keychain by the older key-based
# setup, and checks that the router lets this Mac in.
# Usage: scripts/mac/setup-client.sh http://<pc-magicdns-name>:4000
set -euo pipefail

url="${1:-}"
if [[ ! "$url" =~ ^http://([^/:[:space:]]+):[0-9]+$ ]]; then
  echo "Usage: $0 http://<pc-magicdns-name>:4000   (the name ai-up prints, e.g. http://caps.<tailnet>.ts.net:4000)" >&2
  exit 2
fi
if [[ "${BASH_REMATCH[1]}" =~ ^[0-9.]+$ ]]; then
  echo "Use the PC's MagicDNS name, not its IP: the router is published in HTTP mode, which only answers on the name." >&2
  exit 2
fi

conf="${XDG_CONFIG_HOME:-$HOME/.config}/local-ai"
mkdir -p "$conf"
printf '%s\n' "$url" > "$conf/router-url"
echo "Router URL saved: $url"

removed=0
while security delete-generic-password -s local-ai/router-key >/dev/null 2>&1; do removed=$((removed + 1)); done
if (( removed )); then echo "Removed $removed router key item(s) left in the Keychain by the key-based setup."; fi

# Same non-secret marker header as claude-local.sh; the router lets the Mac in by its Tailscale login.
code="$(curl -s -o /dev/null -m 10 -w '%{http_code}' -H 'x-litellm-api-key: tailscale-identity' "$url/v1/models" || true)"
case "$code" in
  200) echo "Router reachable, and it accepts this Mac's Tailscale login." ;;
  401) echo "Router reachable, but it refuses this Mac's Tailscale login: add the login to D:\\local-ai\\allowed-logins.txt on the PC, or sign the Mac in with the same Tailscale account as the PC." ;;
  000|404|502) echo "No answer from the router (HTTP $code): the stack is probably down (start it with scripts/mac/ai-remote.sh up), or Tailscale is off on one side. The URL is saved; try again once it is up." ;;
  *) echo "Unexpected answer from the router: HTTP $code." ;;
esac
here="$(cd "$(dirname "$0")" && pwd)"
echo "Start Claude Code (Claude models) with: $here/claude-local.sh"
echo "Start OpenCode (local models) with: $here/opencode-local.sh"
oc="$(opencode --version 2>/dev/null || true)"
if [[ "$oc" != "1.19.3" ]]; then   # the pin in scripts/versions.psd1
  echo "OpenCode ${oc:-is not installed}${oc:+ is installed, the pinned version is 1.19.3}: npm install -g opencode-ai@1.19.3"
fi
echo "Check, start or stop the stack on the PC with: $here/ai-remote.sh status|up|down"
