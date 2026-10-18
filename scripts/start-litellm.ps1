# Starts the LiteLLM router with the master key injected from Credential Manager.
# The key lives only in the router process environment (never in a file or argument).
# Usage: scripts\start-litellm.ps1 [-ListenHost 127.0.0.1] [-Port 4000] [-Root D:\local-ai]
param(
  [string]$ListenHost = '127.0.0.1',
  [int]$Port = 4000,
  [string]$Root = $(if ($env:LOCAL_AI_ROOT) { $env:LOCAL_AI_ROOT } else { 'D:\local-ai' })
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\secrets.ps1"

$repo = Split-Path $PSScriptRoot -Parent
$exe = Join-Path $Root 'litellm-venv\Scripts\litellm.exe'
if (-not (Test-Path $exe)) { throw "LiteLLM not found at $exe" }
if (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue) { throw "Port $Port is already in use." }
$logs = Join-Path $Root 'logs'
New-Item -ItemType Directory -Force $logs | Out-Null

$old = @{ K = $env:LITELLM_MASTER_KEY; U = $env:PYTHONUTF8; T = $env:LITELLM_TELEMETRY }
try {
  $env:LITELLM_MASTER_KEY = Get-LocalAiRouterKey
  $env:PYTHONUTF8 = '1'          # LiteLLM's banner crashes on cp1252 when output is redirected
  $env:LITELLM_TELEMETRY = 'False'
  $p = Start-Process $exe -ArgumentList '--config', (Join-Path $repo 'config\litellm.yaml'), '--host', $ListenHost, '--port', $Port `
    -RedirectStandardOutput (Join-Path $logs 'litellm.out.log') -RedirectStandardError (Join-Path $logs 'litellm.err.log') `
    -WindowStyle Hidden -PassThru
} finally {
  $env:LITELLM_MASTER_KEY = $old.K; $env:PYTHONUTF8 = $old.U; $env:LITELLM_TELEMETRY = $old.T
}
for ($i = 0; $i -lt 60; $i++) {
  Start-Sleep 2
  try { Invoke-WebRequest "http://${ListenHost}:$Port/health/liveliness" -UseBasicParsing -TimeoutSec 2 | Out-Null; "LiteLLM up on ${ListenHost}:$Port (pid $($p.Id))"; return } catch {}
}
throw "LiteLLM did not become healthy; see $logs\litellm.err.log"
