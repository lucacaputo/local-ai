#!/usr/bin/env bash
# One-time setup of the local-ai router client on macOS.
# Stores the router URL (not secret) in ~/.config/local-ai/router-url and the router key in the
# login Keychain. The key is typed at the hidden prompt of `security`: it is never an argument,
# an environment variable or a file.
# Usage: scripts/mac/setup-client.sh http://<pc-tailnet-address>:4000
set -euo pipefail

url="${1:-}"
if [[ ! "$url" =~ ^http://[^/[:space:]]+:[0-9]+$ ]]; then
  echo "Usage: $0 http://<pc-tailnet-address>:4000   (the PC's Tailscale IP or MagicDNS name)" >&2
  exit 2
fi

conf="${XDG_CONFIG_HOME:-$HOME/.config}/local-ai"
mkdir -p "$conf"
printf '%s\n' "$url" > "$conf/router-url"
echo "Router URL saved: $url"

echo "Paste the router key at the prompts below (copy it on the PC with scripts\\copy-router-key.ps1)."
security add-generic-password -U -a "$USER" -s local-ai/router-key -w
security find-generic-password -a "$USER" -s local-ai/router-key -w > /dev/null
echo "Router key stored in the login Keychain (service local-ai/router-key)."
echo "Start Claude Code with: $(cd "$(dirname "$0")" && pwd)/claude-local.sh"
