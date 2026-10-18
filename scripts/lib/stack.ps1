# Shared helpers for ai-up.ps1 / ai-down.ps1.  Dot-source:  . "$PSScriptRoot\lib\stack.ps1"

function Get-AiRoot { if ($env:LOCAL_AI_ROOT) { $env:LOCAL_AI_ROOT } else { 'D:\local-ai' } }
function Get-TailscaleExe { 'C:\Program Files\Tailscale\tailscale.exe' }

function Invoke-Quiet([string]$Exe, [string[]]$Arguments) {
  $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try { (& $Exe @Arguments 2>&1 | ForEach-Object { "$_" }) -join "`n" } finally { $ErrorActionPreference = $old }
}

function Get-VramUsedMiB { [int]((Invoke-Quiet 'nvidia-smi' @('--query-gpu=memory.used', '--format=csv,noheader,nounits')) -split "`n")[0] }
function Get-VramFreeMiB { [int]((Invoke-Quiet 'nvidia-smi' @('--query-gpu=memory.free', '--format=csv,noheader,nounits')) -split "`n")[0] }

function Test-Http([string]$Url, [hashtable]$Headers = @{}, [int]$TimeoutSec = 3) {
  try { (Invoke-WebRequest $Url -UseBasicParsing -Headers $Headers -TimeoutSec $TimeoutSec).StatusCode -eq 200 } catch { $false }
}

# Owner of a loopback listener, with the details needed to decide whether it is ours.
function Get-Listener([int]$Port, [string]$Address = '127.0.0.1') {
  $c = Get-NetTCPConnection -LocalPort $Port -LocalAddress $Address -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $c) { return $null }
  $p = Get-CimInstance Win32_Process -Filter "ProcessId=$($c.OwningProcess)" -ErrorAction SilentlyContinue
  [pscustomobject]@{ Pid = $c.OwningProcess; Name = $p.Name; Path = $p.ExecutablePath; CommandLine = $p.CommandLine }
}

function Test-IsStackProcess($Proc, [string]$Root) {
  if (-not $Proc) { return $false }
  ($Proc.Path -and $Proc.Path.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase)) -or ($Proc.CommandLine -match 'litellm')
}

function Stop-Tree([int]$ProcessId) { Invoke-Quiet 'taskkill' @('/PID', "$ProcessId", '/T', '/F') | Out-Null }

# Processes running from the usual game library locations (launchers in Program Files do not count).
$script:DefaultGamePathPattern = '\\steamapps\\common\\|\\Epic Games\\|\\steamGames\\|\\epic_games\\|\\gog_games\\|\\origin_games\\|\\ubi_games\\|\\BattlenetGames\\|\\GOG Galaxy\\Games\\'
function Find-GameProcesses([string]$Pattern = $script:DefaultGamePathPattern) {
  Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path -match $Pattern } |
    Select-Object -ExpandProperty ProcessName -Unique
}

function Get-StateFile([string]$Root) { Join-Path $Root 'run\stack.json' }
