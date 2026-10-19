#!/usr/bin/env bash
# Checks, starts or stops the local AI stack on the PC from macOS, through the control service
# (scripts\control-service.py) that the PC publishes under /control on the router's tailnet port
# (TASK-025, TASK-026, TASK-027). No key: as for claude-local.sh, tailscale serve tells the PC which
# Tailscale login is calling. The PC answers in JSON, turned into text by osascript (JavaScript), which
# every Mac has. Router URL: $LOCAL_AI_ROUTER, else ~/.config/local-ai/router-url (setup-client.sh).
# Usage: scripts/mac/ai-remote.sh status|up|down
# Exit status: 0 done, 1 refused or failed on the PC, 2 usage or no router URL, 3 PC not reachable.
set -euo pipefail

case "${1:-}" in
  status) method=GET; max=20 ;;
  up|down) method=POST; max=330 ;;   # the PC gives ai-up and ai-down 300 s
  *) echo "Usage: $0 status|up|down" >&2; exit 2 ;;
esac
cmd="$1"
here="$(cd "$(dirname "$0")" && pwd)"
conf="${XDG_CONFIG_HOME:-$HOME/.config}/local-ai"
router="${LOCAL_AI_ROUTER:-}"
[[ -z "$router" && -r "$conf/router-url" ]] && router="$(<"$conf/router-url")"
if [[ -z "$router" ]]; then
  echo "No router URL. Run scripts/mac/setup-client.sh first." >&2
  exit 2
fi
router="${router%/}"
host="${router#*://}"; host="${host%%[:/]*}"

# Turns the control service's JSON answer into text. argv: command, HTTP code, body.
read -r -d '' js <<'JS' || true
function stackLine(s) {
  var line;
  if (s.stack === "up") line = "Stack up: " + (s.model_loaded ? s.model_loaded + " loaded." : "no model loaded yet (the first request loads one).");
  else if (s.stack === "down") line = "Stack down.";
  else line = "Stack partly running (router " + (s.router ? "up" : "down") + ", llama-swap " + (s.llama_swap ? "up" : "down") + ")." +
    (s.running ? "" : " Run ai-remote.sh down, then up.");
  if (s.vram_used_mib != null) line += " VRAM: " + s.vram_used_mib + " of " + s.vram_total_mib + " MiB used.";
  if (s.running) line += " Running now: ai-" + s.running + ".";
  return line;
}
function run(argv) {
  var b;
  try { b = JSON.parse(argv[2]); } catch (e) { return "Unexpected answer from the PC (HTTP " + argv[1] + "): " + argv[2].slice(0, 300); }
  var out = [];
  if (b.error) out.push(b.error);
  (b.output || []).forEach(function (l) {
    if (!/^Use: scripts\\/.test(l)) out.push(l);   // ai-up's hint for the PC user
  });
  if (argv[0] === "status" && b.stack) out.push(stackLine(b));
  return out.join("\n");
}
JS

body="$(mktemp)"; err="$(mktemp)"
trap 'rm -f "$body" "$err"' EXIT
case "$cmd" in
  up) echo "Starting the stack on the PC (about 15 s)..." ;;
  down) echo "Stopping the stack on the PC..." ;;
esac
w="$(curl -sS -o "$body" -w '%{http_code} %{time_connect}' --connect-timeout 10 -m "$max" -X "$method" "$router/control/$cmd" 2>"$err")" && rc=0 || rc=$?
code="${w%% *}"
if (( rc )); then
  msg="$(sed -n '1s/^curl: ([0-9]*) //p' "$err")"
  case "$rc" in
    6) echo "Cannot resolve $host: Tailscale is off on this Mac. Turn it on and try again." ;;
    # an unpublished port times out too (the PC's firewall drops it), so it cannot be told apart from a PC that is off
    28) if [[ "${w#* }" =~ ^0(\.0*)?$ ]]; then echo "The PC does not answer: it is asleep or off, Tailscale is off there, or the control service was never installed (scripts\\install-control.ps1)."
        else echo "The PC took the request but did not answer within $max s. Check with: $0 status"; fi ;;
    7) echo "Cannot connect to the PC ($msg): Tailscale is off on one side, or the PC publishes nothing on that port (run scripts\\install-control.ps1 there)." ;;
    *) echo "Cannot reach the PC ($msg)." ;;
  esac >&2
  exit 3
fi

case "$code" in
  404) echo "The PC does not publish the control service (/control): run scripts\\install-control.ps1 there." >&2; exit 3 ;;
  502) echo "The PC is on, but its control service is not running. The PC restarts it within 10 minutes, or run scripts\\install-control.ps1 there." >&2; exit 3 ;;
esac
text="$(osascript -l JavaScript -e "$js" "$cmd" "$code" "$(<"$body")")"
case "$code" in
  200)
    echo "$text"
    [[ "$cmd" == up ]] && echo "Start Claude Code with: $here/claude-local.sh"
    exit 0 ;;
  401) echo "$text" >&2
       echo "Sign this Mac in to Tailscale with the PC's account, or list its login in D:\\local-ai\\allowed-logins.txt on the PC." >&2 ;;
  409) echo "$text. Check again in a moment with: $0 status" >&2 ;;
  422) if [[ "$cmd" == up ]]; then echo "The PC did not start the stack:" >&2; else echo "The PC could not stop the stack:" >&2; fi
       echo "$text" >&2 ;;
  *) echo "Unexpected answer from the PC (HTTP $code): $text" >&2 ;;
esac
exit 1
