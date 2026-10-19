# Starts the control service (scripts\control-service.py, TASK-025) detached on 127.0.0.1:4100, with the
# router's Tailscale allowlist injected, and waits until it answers. It only starts and stops the stack when
# asked; it never starts it by itself. Publishing it on the tailnet and starting it at logon are TASK-026.
#
#   scripts\start-control.ps1 [-Stop] [-Root D:\local-ai]
#     -Stop  end the control service (the stack itself is left as it is)
param(
  [switch]$Stop,
  [string]$Root = $(if ($env:LOCAL_AI_ROOT) { $env:LOCAL_AI_ROOT } else { 'D:\local-ai' })
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\stack.ps1"
$port = 4100
$running = Get-Listener $port
$ours = $running -and ($running.CommandLine -match 'control-service\.py')

if ($Stop) {
  if ($ours) { Stop-Tree $running.Pid; "Control service stopped (pid $($running.Pid))." }
  elseif ($running) { Write-Warning "Port $port is held by '$($running.Name)' (pid $($running.Pid)), not the control service; left alone." }
  else { 'Control service is not running.' }
  return
}
if ($ours) { "Control service already running (pid $($running.Pid))."; return }
if ($running) { throw "Port $port is held by '$($running.Name)' (pid $($running.Pid))." }

$py = Join-Path $Root 'litellm-venv\Scripts\python.exe'
if (-not (Test-Path $py)) { throw "Python not found at $py. Run scripts\install.ps1 first." }
$logs = Join-Path $Root 'logs'
New-Item -ItemType Directory -Force $logs | Out-Null
$logins = @(Get-AllowedLogins $Root)
$old = $env:LOCAL_AI_ALLOWED_LOGINS
try {
  $env:LOCAL_AI_ALLOWED_LOGINS = $logins -join ','   # read by control-service.py, same list as the router
  Start-Detached $py @((Join-Path $PSScriptRoot 'control-service.py'), $Root) (Join-Path $logs 'control.out.log') (Join-Path $logs 'control.err.log') | Out-Null
} finally {
  $env:LOCAL_AI_ALLOWED_LOGINS = $old
}
for ($i = 0; $i -lt 20 -and -not (Test-Http "http://127.0.0.1:$port/health"); $i++) { Start-Sleep -Milliseconds 500 }
if (-not (Test-Http "http://127.0.0.1:$port/health")) { throw "Control service did not start; see $logs\control.err.log" }
"Control service running on 127.0.0.1:$port (pid $((Get-Listener $port).Pid)), $($logins.Count) allowed login(s)."
if (-not $logins) { Write-Warning 'No allowed logins (Tailscale signed out and no allowed-logins.txt): every request will be refused.' }
