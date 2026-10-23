# TASK-034: the whole quality set, model by model (so llama-swap swaps once per model), each task $Reps times.
#   bench\quality\run-all.ps1 [-Models local-coder] [-Tasks t1,...] [-Reps 2] [-Client opencode] [-Out ...]
param(
  [string[]]$Models = @('local-coder'),   # TASK-034 compared local-coder-q6 and local-coder-38, replaced by it in TASK-036
  [string[]]$Tasks = @('t1', 't2', 't3', 't4', 't5', 't6', 't6c'),
  [int]$Reps = 2,
  [string]$Out = 'D:\local-ai\scratch\quality\runs',
  [ValidateSet('claude', 'opencode')][string]$Client = 'claude'
)
if ($Client -eq 'opencode') { $Tasks = @($Tasks | Where-Object { $_ -ne 't6c' }) }   # t6c is a Claude Code control
$ErrorActionPreference = 'Stop'
foreach ($m in $Models) {
  foreach ($r in 1..$Reps) {
    foreach ($t in $Tasks) {
      $n = if ($Client -eq 'opencode') { "oc-$m-$t-r$r" } else { "$m-$t-r$r" }
      if (Test-Path (Join-Path $Out $n)) { "skip $n (already run)"; continue }
      try { & "$PSScriptRoot\run.ps1" -Model $m -Task $t -Rep $r -Out $Out -Client $Client } catch { Write-Warning "$m $t r$r failed: $($_.Exception.Message)" }
    }
  }
}
