# Stops the local AI stack and frees the GPU: unpublishes the router's tailnet route, stops the router,
# llama-swap and llama-server, then waits for VRAM to drop back to idle. Safe to run when nothing runs.
param([int]$WaitSec = 30)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\stack.ps1"
$clock = [Diagnostics.Stopwatch]::StartNew()
$root = Get-AiRoot
$stateFile = Get-StateFile $root
$before = Get-VramUsedMiB
$baseline = $null
if (Test-Path $stateFile) {
  # a state file cut short by a crash must not stop the cleanup: fall back to the fixed idle target
  try { $baseline = [int](Get-Content $stateFile -Raw | ConvertFrom-Json).vramBaselineMiB } catch { Write-Warning "Ignoring unreadable $stateFile." }
}
$stopped = @()

# tailnet publishing first, so nothing forwards to a dying router. Only the router's "/" route is removed; other
# routes on port 4000 (the control service) stay. A TCP forward is how ai-up published it before TASK-023.
$ts = Get-TailscaleExe
if (Test-Path $ts) {
  $serve = Get-Serve4000
  if ($serve.Mode -eq 'tcp') { Invoke-Quiet $ts @('serve', '--tcp=4000', 'off') | Out-Null; $stopped += 'tailnet publishing' }
  elseif ($serve.Paths -contains '/') { Invoke-Quiet $ts @('serve', '--http', '4000', '--set-path', '/', 'off') | Out-Null; $stopped += 'tailnet publishing' }
}

# processes: only things that belong to the stack are touched. Router first, then llama-swap, which
# takes its llama-server child down with it; give that child a moment to exit before judging it.
function Stop-StackListener([int]$Port, [string]$Label, [int]$GraceSec = 0) {
  for ($i = 0; $i -le $GraceSec; $i++) {
    $l = Get-Listener $Port
    if (-not $l) { return }
    if ($i -lt $GraceSec) { Start-Sleep 1; continue }
    if (Test-IsStackProcess $l $root) { Stop-Tree $l.Pid; $script:stopped += "$Label (pid $($l.Pid))" }
    else { Write-Warning "Port $Port is held by '$($l.Name)' (pid $($l.Pid)), which is not part of the stack; left alone." }
  }
}
Stop-StackListener 4000 'router'
Stop-StackListener 8080 'llama-swap'
Stop-StackListener 10001 'llama-server' -GraceSec 5
Stop-StackListener 10002 'llama-server (q6)' -GraceSec 5
Stop-StackListener 10003 'llama-server (qwen3.8)' -GraceSec 5
# launcher shims and strays from our install folder
Get-Process litellm, llama-swap, llama-server -ErrorAction SilentlyContinue |
  Where-Object { $_.Path -and $_.Path.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) } |
  ForEach-Object { Stop-Tree $_.Id; $stopped += "$($_.ProcessName) (pid $($_.Id))" }

# wait for the GPU to settle
$target = if ($baseline) { $baseline + 600 } else { 3000 }
$after = Get-VramUsedMiB
for ($i = 0; $i -lt $WaitSec -and $after -gt $target; $i++) { Start-Sleep 1; $after = Get-VramUsedMiB }
if (Test-Path $stateFile) { Remove-Item $stateFile -Force }

if ($stopped) { "Stopped: $($stopped -join ', ')." } else { 'Nothing was running.' }
"VRAM used: $before MiB -> $after MiB in $([math]::Round($clock.Elapsed.TotalSeconds, 1)) s$(if ($baseline) { " (idle before ai-up: $baseline MiB)" })."
if ($after -gt $target) { Write-Warning "VRAM is still above $target MiB; something else is using the GPU." }
