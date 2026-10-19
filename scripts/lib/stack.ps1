# Shared helpers for ai-up.ps1 / ai-down.ps1.  Dot-source:  . "$PSScriptRoot\lib\stack.ps1"

function Get-AiRoot { if ($env:LOCAL_AI_ROOT) { $env:LOCAL_AI_ROOT } else { 'D:\local-ai' } }
function Get-TailscaleExe { 'C:\Program Files\Tailscale\tailscale.exe' }

function Invoke-Quiet([string]$Exe, [string[]]$Arguments) {
  $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try { (& $Exe @Arguments 2>&1 | ForEach-Object { "$_" }) -join "`n" } finally { $ErrorActionPreference = $old }
}

# Starts a hidden background process with stdout/stderr going to log files. Start-Process with
# -RedirectStandardOutput makes the child inherit the caller's own output pipe, so a caller that waits for
# that pipe to close (powershell.exe run from WSL, or any pipeline capturing the output) hangs for as long as
# the child lives. Going through cmd.exe, which Start-Process starts without handle inheritance, avoids that.
# The process returned is the cmd.exe wrapper; it ends when the child ends.
function Start-Detached([string]$Exe, [string[]]$Arguments, [string]$OutLog, [string]$ErrLog) {
  $line = ((@($Exe) + $Arguments | ForEach-Object { "`"$_`"" }) -join ' ') + " >`"$OutLog`" 2>`"$ErrLog`""
  Start-Process cmd.exe -ArgumentList "/c `"$line`"" -WindowStyle Hidden -PassThru
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

# This PC's MagicDNS name (caps.<tailnet>.ts.net); HTTP-mode serve only answers on the name, not the IP (TASK-022).
function Get-TailnetName {
  try { ((Invoke-Quiet (Get-TailscaleExe) @('status', '--json')) | ConvertFrom-Json).Self.DNSName.TrimEnd('.') } catch { $null }
}

# Tailscale logins the router lets in without the key (TASK-023): the lines of <root>\allowed-logins.txt when that
# file exists (# starts a comment), otherwise the login this PC itself is signed in with. Kept out of the repo.
function Get-AllowedLogins([string]$Root) {
  $file = Join-Path $Root 'allowed-logins.txt'
  if (Test-Path $file) { return @(Get-Content $file | ForEach-Object { ($_ -replace '#.*$', '').Trim() } | Where-Object { $_ }) }
  try { $s = (Invoke-Quiet (Get-TailscaleExe) @('status', '--json')) | ConvertFrom-Json } catch { return @() }
  $u = $s.User."$($s.Self.UserID)"
  if ($u -and $u.LoginName) { @($u.LoginName) } else { @() }
}

# tailscale serve configuration of port 4000: Mode 'tcp' (how it was published before TASK-023), 'http' or $null,
# and the HTTP route paths on it ('/' is the router, '/control' the control service).
function Get-Serve4000 {
  $none = [pscustomobject]@{ Mode = $null; Paths = @() }
  try { $s = (Invoke-Quiet (Get-TailscaleExe) @('serve', 'status', '--json')) | ConvertFrom-Json } catch { return $none }
  $p = $s.TCP.'4000'
  if (-not $p) { return $none }
  if ($p.TCPForward) { return [pscustomobject]@{ Mode = 'tcp'; Paths = @() } }
  $paths = @($s.Web.PSObject.Properties | Where-Object { $_.Name -like '*:4000' } | ForEach-Object { $_.Value.Handlers.PSObject.Properties.Name })
  [pscustomobject]@{ Mode = 'http'; Paths = $paths }
}
