# Launches OpenCode against the local router, for the local models (TASK-038; Claude models stay in claude-local.ps1).
# The router key is read from Credential Manager and exists only in the OpenCode process environment; nothing is
# written to disk. config\opencode.json names the models, their windows and effort, and the permissions.
# All arguments are passed to opencode unchanged (--auto approves what the config would ask for, for that session).
# Router URL: $env:LOCAL_AI_ROUTER, default http://127.0.0.1:4000 (use the tailnet address remotely).
# Usage: scripts\opencode-local.ps1 [opencode arguments...]
. "$PSScriptRoot\lib\secrets.ps1"

$repo = Split-Path $PSScriptRoot -Parent
$router = if ($env:LOCAL_AI_ROUTER) { $env:LOCAL_AI_ROUTER } else { 'http://127.0.0.1:4000' }
$names = 'OPENCODE_CONFIG', 'LOCAL_AI_ROUTER_URL', 'LOCAL_AI_ROUTER_KEY'
$old = @{}; foreach ($n in $names) { $old[$n] = [Environment]::GetEnvironmentVariable($n, 'Process') }
try {
  $env:OPENCODE_CONFIG = Join-Path $repo 'config\opencode.json'
  $env:LOCAL_AI_ROUTER_URL = $router
  $env:LOCAL_AI_ROUTER_KEY = Get-LocalAiRouterKey
  & opencode @args
} finally {
  foreach ($n in $names) { [Environment]::SetEnvironmentVariable($n, $old[$n], 'Process') }   # do not leak into the calling shell
}
