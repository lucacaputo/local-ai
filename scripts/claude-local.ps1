# Launches Claude Code against the local router. The router key is read from Credential Manager
# and exists only in the Claude Code process environment; nothing is written to disk.
# Does not set ANTHROPIC_API_KEY / ANTHROPIC_AUTH_TOKEN, so the subscription login stays in use.
# All arguments are passed to claude unchanged (no named parameters here, so -p etc. reach claude).
# Router URL: $env:LOCAL_AI_ROUTER, default http://127.0.0.1:4000 (use the tailnet address remotely).
# Usage: scripts\claude-local.ps1 [claude arguments...]
. "$PSScriptRoot\lib\secrets.ps1"

$repo = Split-Path $PSScriptRoot -Parent
$router = if ($env:LOCAL_AI_ROUTER) { $env:LOCAL_AI_ROUTER } else { 'http://127.0.0.1:4000' }
$old = @{ B = $env:ANTHROPIC_BASE_URL; H = $env:ANTHROPIC_CUSTOM_HEADERS }
try {
  $env:ANTHROPIC_BASE_URL = $router
  $env:ANTHROPIC_CUSTOM_HEADERS = "x-litellm-api-key: Bearer $(Get-LocalAiRouterKey)"
  & claude --settings (Join-Path $repo 'config\claude-settings.json') @args
} finally {
  $env:ANTHROPIC_BASE_URL = $old.B; $env:ANTHROPIC_CUSTOM_HEADERS = $old.H   # do not leak into the calling shell
}
