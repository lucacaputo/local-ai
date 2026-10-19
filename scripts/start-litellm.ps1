# Starts the LiteLLM router with the master key injected from Credential Manager.
# The key lives only in the router process environment (never in a file or argument).
# Loopback only; remote devices reach it through `tailscale serve --tcp 4000 tcp://127.0.0.1:4000`.
# Usage: scripts\start-litellm.ps1 [-ListenHost 127.0.0.1] [-Port 4000] [-Root D:\local-ai]
param(
  [string]$ListenHost = '127.0.0.1',
  [int]$Port = 4000,
  [string]$Root = $(if ($env:LOCAL_AI_ROOT) { $env:LOCAL_AI_ROOT } else { 'D:\local-ai' })
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\secrets.ps1"
. "$PSScriptRoot\lib\stack.ps1"

# The router stays on loopback; tailnet access is published by `tailscale serve` (decision-006).
if ($ListenHost -notin @('127.0.0.1', '::1', 'localhost')) { throw "Refusing to bind the router to '$ListenHost': loopback only (see decision-006)." }

$repo = Split-Path $PSScriptRoot -Parent
$exe = Join-Path $Root 'litellm-venv\Scripts\litellm.exe'
if (-not (Test-Path $exe)) { throw "LiteLLM not found at $exe" }
# Another listener on the same port is fine only on a different address (tailscaled publishes the tailnet address).
$clash = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
  Where-Object { $_.LocalAddress -in @($ListenHost, '0.0.0.0', '::') }
if ($clash) { throw "Port $Port is already in use on $($clash.LocalAddress) (pid $($clash.OwningProcess))." }
$logs = Join-Path $Root 'logs'
New-Item -ItemType Directory -Force $logs | Out-Null

$old = @{ K = $env:LITELLM_MASTER_KEY; U = $env:PYTHONUTF8; T = $env:LITELLM_TELEMETRY }
try {
  $env:LITELLM_MASTER_KEY = Get-LocalAiRouterKey
  $env:PYTHONUTF8 = '1'          # LiteLLM's banner crashes on cp1252 when output is redirected
  $env:LITELLM_TELEMETRY = 'False'
  Start-Detached $exe @('--config', (Join-Path $repo 'config\litellm.yaml'), '--host', $ListenHost, '--port', "$Port") `
    (Join-Path $logs 'litellm.out.log') (Join-Path $logs 'litellm.err.log') | Out-Null
} finally {
  $env:LITELLM_MASTER_KEY = $old.K; $env:PYTHONUTF8 = $old.U; $env:LITELLM_TELEMETRY = $old.T
}
for ($i = 0; $i -lt 60; $i++) {
  Start-Sleep 2
  try { Invoke-WebRequest "http://${ListenHost}:$Port/health/liveliness" -UseBasicParsing -TimeoutSec 2 | Out-Null; "LiteLLM up on ${ListenHost}:$Port (pid $((Get-Listener $Port $ListenHost).Pid))"; return } catch {}
}
throw "LiteLLM did not become healthy; see $logs\litellm.err.log"
