# TASK-034: the whole quality set, model by model (so llama-swap swaps once per model), each task $Reps times.
#   bench\quality\run-all.ps1 [-Models local-coder-q6,local-coder-38] [-Tasks t1,...] [-Reps 2] [-Out ...]
param(
  [string[]]$Models = @('local-coder-q6', 'local-coder-38'),
  [string[]]$Tasks = @('t1', 't2', 't3', 't4', 't5', 't6', 't6c'),
  [int]$Reps = 2,
  [string]$Out = 'D:\local-ai\scratch\quality\runs'
)
$ErrorActionPreference = 'Stop'
foreach ($m in $Models) {
  foreach ($r in 1..$Reps) {
    foreach ($t in $Tasks) {
      if (Test-Path (Join-Path $Out "$m-$t-r$r")) { "skip $m-$t-r$r (already run)"; continue }
      try { & "$PSScriptRoot\run.ps1" -Model $m -Task $t -Rep $r -Out $Out } catch { Write-Warning "$m $t r$r failed: $($_.Exception.Message)" }
    }
  }
}
