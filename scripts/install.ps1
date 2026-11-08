# Installs the local AI stack's binaries at the pinned versions (scripts\versions.psd1, decision-002).
# Safe to run repeatedly: every step checks first and changes nothing when it is already in place.
#
#   scripts\install.ps1                  install what is missing under -Root
#   scripts\install.ps1 -CheckOnly       report what is present/missing, change nothing (exit 2 if work is needed)
#   scripts\install.ps1 -SkipModel       skip the 16 GB model download
#
# Missing uv and Tailscale are installed with winget, and OpenCode with npm, at the pinned versions
# (Tailscale shows a Windows permission prompt and needs a one-time sign-in afterwards). The NVIDIA
# driver and Node.js are never installed automatically: a missing or too-old driver stops the script
# with instructions, a missing Node.js only warns.
#
# Everything lands under -Root (default $env:LOCAL_AI_ROOT or D:\local-ai), outside the repo (decision-003).
param(
  [string]$Root = $(if ($env:LOCAL_AI_ROOT) { $env:LOCAL_AI_ROOT } else { 'D:\local-ai' }),
  [switch]$SkipModel,
  [switch]$CheckOnly,
  [string]$NvidiaSmi = 'nvidia-smi',
  [string]$Tailscale = 'C:\Program Files\Tailscale\tailscale.exe',
  [string]$Uv
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$v = Import-PowerShellDataFile (Join-Path $PSScriptRoot 'versions.psd1')

function Invoke-Native([string]$Exe, [string[]]$Arguments) {
  $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try { $out = (& $Exe @Arguments 2>&1 | ForEach-Object { "$_" }) -join "`n"; $code = $LASTEXITCODE }
  finally { $ErrorActionPreference = $old }
  [pscustomobject]@{ Output = $out; Code = $code }
}


function Install-Winget([string]$Id, [string]$Version) {
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw "winget is not available; install $Id $Version manually." }
  $r = Invoke-Native 'winget' @('install', '--id', $Id, '--version', $Version, '--exact', '--silent', '--accept-package-agreements', '--accept-source-agreements')
  # winget exits non-zero when the exact version is already installed; the caller re-checks the result
  if ($r.Code -ne 0 -and $r.Output -notmatch 'already installed|No available upgrade|No newer package') { throw "winget install $Id failed (exit $($r.Code)): $($r.Output)" }
}

function Find-Uv {
  $cmd = Get-Command uv -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  # shells opened before the winget install do not have uv on PATH yet
  @(
    Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages') -Filter 'uv.exe' -Recurse -ErrorAction SilentlyContinue |
      Select-Object -First 1 -ExpandProperty FullName
    Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\uv.exe'
  ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}

# ---------------------------------------------------------------- preflight
$problems = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]
$needed = New-Object System.Collections.Generic.List[string]   # prerequisites -CheckOnly found missing

$smi = Get-Command $NvidiaSmi -ErrorAction SilentlyContinue
if (-not $smi) {
  $problems.Add("NVIDIA driver not found ('$NvidiaSmi' is not available). Install a current NVIDIA driver (RTX 50-series needs CUDA $($v.MinCudaVersion)+).")
} else {
  $q = Invoke-Native $smi.Source @('--query-gpu=name,driver_version,compute_cap', '--format=csv,noheader')
  $gpu = ($q.Output -split "`n")[0] -split ',\s*'
  if ($q.Code -ne 0 -or $gpu.Count -lt 3) {
    $problems.Add("nvidia-smi could not report the GPU: $($q.Output)")
  } else {
    if ([version]$gpu[2] -lt [version]$v.MinComputeCapability) {
      $problems.Add("GPU '$($gpu[0])' has compute capability $($gpu[2]); the pinned CUDA build needs $($v.MinComputeCapability)+ (RTX 50-series).")
    }
    $full = Invoke-Native $smi.Source @()
    if ($full.Output -match 'CUDA (?:UMD )?Version:\s*([\d.]+)') {
      if ([version]$Matches[1] -lt [version]$v.MinCudaVersion) {
        $problems.Add("Driver supports CUDA $($Matches[1]); need $($v.MinCudaVersion)+. Update the NVIDIA driver.")
      } else { $cudaOk = $Matches[1] }
    } else { $problems.Add('Could not read the CUDA version from nvidia-smi.') }
    $gpuLine = "$($gpu[0]), driver $($gpu[1]), compute $($gpu[2]), CUDA $cudaOk"
  }
}

$installed = New-Object System.Collections.Generic.List[string]
if (-not (Test-Path $Tailscale)) {
  if ($CheckOnly) { $needed.Add("Tailscale $($v.Tailscale.Version)") }
  elseif (-not $problems.Count) {   # skip installs when the GPU check already failed
    "Installing Tailscale $($v.Tailscale.Version) with winget (accept the Windows permission prompt) ..."
    try { Install-Winget $v.Tailscale.WingetId $v.Tailscale.Version } catch { $problems.Add("Tailscale install failed: $($_.Exception.Message)") }
    if (Test-Path $Tailscale) { $installed.Add('Tailscale'); $warnings.Add('Tailscale was just installed: sign in once with: tailscale login') }
    elseif (-not $problems.Count) { $problems.Add("Tailscale was installed but '$Tailscale' does not exist. Check the install location.") }
  }
}
if (Test-Path $Tailscale) {
  $st = Invoke-Native $Tailscale @('status')
  if ($st.Output -match 'Logged out' -and -not ($warnings -match 'sign in once')) { $warnings.Add('Tailscale is installed but logged out; run: tailscale login') }
  $tsLine = if ($st.Output -match 'Logged out') { 'installed, logged out' } else { 'installed' }
}

if (-not $Uv) { $Uv = Find-Uv }
if (-not $Uv -or -not (Test-Path $Uv)) {
  if ($CheckOnly) { $needed.Add("uv $($v.Uv.Version)") }
  elseif (-not $problems.Count) {
    "Installing uv $($v.Uv.Version) with winget ..."
    try { Install-Winget $v.Uv.WingetId $v.Uv.Version } catch { $problems.Add("uv install failed: $($_.Exception.Message)") }
    $Uv = Find-Uv
    if ($Uv) { $installed.Add('uv') } elseif (-not $problems.Count) { $problems.Add('uv was installed but uv.exe was not found.') }
  }
}
if ($Uv -and (Test-Path $Uv)) {
  $uvVer = (Invoke-Native $Uv @('--version')).Output
  if ($uvVer -notmatch [regex]::Escape($v.Uv.Version)) { $warnings.Add("uv is '$uvVer'; pinned version is $($v.Uv.Version).") }
}

# OpenCode (TASK-038), the client for local models: installed with npm; Node.js itself is not installed here
$npm = Get-Command npm.cmd -ErrorAction SilentlyContinue
$ocSpec = "$($v.OpenCode.Npm)@$($v.OpenCode.Version)"
if (-not (Get-Command opencode.cmd -ErrorAction SilentlyContinue)) {
  if (-not $npm) { $warnings.Add("Node.js (npm) not found: install Node 22.18+, then rerun to install OpenCode $($v.OpenCode.Version), the client for local models.") }
  elseif ($CheckOnly) { $needed.Add("OpenCode $($v.OpenCode.Version)") }
  elseif (-not $problems.Count) {
    "Installing OpenCode $($v.OpenCode.Version) with npm ..."
    $r = Invoke-Native $npm.Source @('install', '-g', $ocSpec)
    if ($r.Code -eq 0 -and (Get-Command opencode.cmd -ErrorAction SilentlyContinue)) { $installed.Add('OpenCode') }
    else { $problems.Add("npm install -g $ocSpec failed (exit $($r.Code)): $($r.Output)") }
  }
}
if (Get-Command opencode.cmd -ErrorAction SilentlyContinue) {
  $ocVer = (Invoke-Native 'opencode.cmd' @('--version')).Output.Trim()
  if ($ocVer -ne $v.OpenCode.Version) { $warnings.Add("OpenCode is '$ocVer'; pinned version is $($v.OpenCode.Version) (npm install -g $ocSpec).") }
}

# Docker Desktop (TASK-041): checked, never installed here; the agent sandboxes need it, the coding stack does not
$dockerLine = 'not installed (agent sandboxes only; README, Requirements)'
$dockerUp = $false
if (Get-Command docker -ErrorAction SilentlyContinue) {
  $dd = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Docker Desktop' -ErrorAction SilentlyContinue).DisplayVersion
  $dockerUp = (Invoke-Native 'docker' @('info', '--format', '{{.OSType}}')).Output -match 'linux'
  $dockerLine = "Docker Desktop $dd, $(if ($dockerUp) { 'running' } else { 'not running' })"
  if ($dd -and $dd -ne $v.DockerDesktop.Version) { $warnings.Add("Docker Desktop is $dd; pinned version is $($v.DockerDesktop.Version) (winget install --id $($v.DockerDesktop.WingetId) --version $($v.DockerDesktop.Version)).") }
}
$sandboxFrom = Select-String -Path (Join-Path $PSScriptRoot '..\sandbox\Dockerfile') -Pattern '^LABEL local-ai.openclaw="(.+)"' | ForEach-Object { $_.Matches[0].Groups[1].Value }
if ($sandboxFrom -ne $v.Sandbox.OpenClaw) { $problems.Add("sandbox\Dockerfile is labelled OpenClaw $sandboxFrom but versions.psd1 pins $($v.Sandbox.OpenClaw).") }

# control service (TASK-026): reported only; it is optional, so it is never installed or counted as missing here
$ctlLine = if (Get-ScheduledTask -TaskName 'local-ai-control' -ErrorAction SilentlyContinue) { 'installed (starts at logon)' } else { 'not installed (optional: scripts\install-control.ps1)' }
if (Get-NetTCPConnection -State Listen -LocalPort 4100 -LocalAddress 127.0.0.1 -ErrorAction SilentlyContinue) { $ctlLine += ', running' }
if ($tsLine -eq 'installed') {
  $web = try { ((Invoke-Native $Tailscale @('serve', 'status', '--json')).Output | ConvertFrom-Json).Web } catch { $null }
  if ($web -and ($web.PSObject.Properties | Where-Object { $_.Value.Handlers.PSObject.Properties.Name -contains '/control' })) { $ctlLine += ', /control published' }
}

$rootDrive = Split-Path -Qualifier $Root
if ($rootDrive -and (Test-Path "$rootDrive\")) {
  $freeGb = [math]::Round((Get-PSDrive ($rootDrive.TrimEnd(':'))).Free / 1GB)
  $missingModels = @($v.Models | Where-Object { -not (Test-Path (Join-Path $Root "models\$($_.File)")) })
  $modelGb = [math]::Ceiling((($missingModels | ForEach-Object { $_.Size } | Measure-Object -Sum).Sum) / 1GB)
  $needGb = if ($SkipModel) { 3 } else { 3 + $modelGb }
  if ($freeGb -lt $needGb -and $missingModels.Count) {
    $problems.Add("Only $freeGb GB free on $rootDrive; need about $needGb GB for -Root '$Root'.")
  }
} else { $problems.Add("Drive for -Root '$Root' does not exist.") }

"Local AI install -> $Root$(if ($CheckOnly) { '  [check only]' })"
if ($gpuLine) { "  GPU        $gpuLine" }
if ($tsLine)  { "  Tailscale  $tsLine" }
if ($uvVer)   { "  uv         $uvVer" }
if ($ocVer)   { "  OpenCode   $ocVer" }
if ($ctlLine) { "  control    $ctlLine" }
"  Docker     $dockerLine"
foreach ($n in $needed) { "  [missing]  $n (would be installed with winget or npm)" }
foreach ($i in $installed) { "  [install]  $i installed" }
foreach ($w in $warnings) { "  warning: $w" }
if ($problems.Count) {
  ''
  'Preflight failed:'
  $problems | ForEach-Object { "  - $_" }
  exit 1
}

# ---------------------------------------------------------------- steps
$bin = Join-Path $Root 'bin'
$changed = $installed.Count; $missing = $needed.Count

function Step([string]$Name, [scriptblock]$Present, [scriptblock]$Install) {
  if (& $Present) { "  [ok]       $Name"; return }
  if ($CheckOnly) { "  [missing]  $Name"; $script:missing++; return }
  "  [install]  $Name ..."
  & $Install
  if (-not (& $Present)) { throw "${Name}: verification failed after install." }
  $script:changed++
}

function Get-Verified([string]$Url, [string]$Sha256, [string]$Dest) {
  New-Item -ItemType Directory -Force (Split-Path $Dest) | Out-Null
  $r = Invoke-Native 'curl.exe' @('-fL', '--retry', '3', '-sS', '-o', $Dest, $Url)
  if ($r.Code -ne 0) { Remove-Item $Dest -Force -ErrorAction SilentlyContinue; throw "Download failed ($Url): $($r.Output)" }
  $got = (Get-FileHash $Dest -Algorithm SHA256).Hash.ToLower()
  if ($got -ne $Sha256.ToLower()) { Remove-Item $Dest -Force; throw "SHA-256 mismatch for $Url`n  expected $Sha256`n  got      $got" }
}

function Install-Archive($Spec, [string]$TargetDir) {
  $zip = Join-Path $Root "downloads\$($Spec.Archive)"
  Get-Verified $Spec.Url $Spec.Sha256 $zip
  Expand-Archive -Path $zip -DestinationPath $TargetDir -Force
  Remove-Item $zip -Force
}

$llamaDir = Join-Path $bin $v.LlamaCpp.Dir
$llamaBuild = $v.LlamaCpp.Build.TrimStart('b')
Step "llama.cpp $($v.LlamaCpp.Build) (CUDA 13.4)" {
  $exe = Join-Path $llamaDir 'llama-server.exe'
  (Test-Path $exe) -and ((Invoke-Native $exe @('--version')).Output -match "build $llamaBuild\b")
} {
  Install-Archive $v.LlamaCpp $llamaDir
  Install-Archive $v.LlamaCpp.CudaRt $llamaDir
}

$swapDir = Join-Path $bin $v.LlamaSwap.Dir
Step "llama-swap $($v.LlamaSwap.Version)" {
  $exe = Join-Path $swapDir 'llama-swap.exe'
  (Test-Path $exe) -and ((Invoke-Native $exe @('-version')).Output -match [regex]::Escape($v.LlamaSwap.Version))
} {
  Install-Archive $v.LlamaSwap $swapDir
}

$venv = Join-Path $Root $v.LiteLlm.VenvDir
$py = Join-Path $venv 'Scripts\python.exe'
Step "LiteLLM $($v.LiteLlm.Version) in $($v.LiteLlm.VenvDir) (Python $($v.LiteLlm.Python), uv)" {
  (Test-Path $py) -and ((Invoke-Native $py @('-c', "import importlib.metadata as m; print(m.version('litellm'))")).Output.Trim() -eq $v.LiteLlm.Version)
} {
  $r = Invoke-Native $Uv @('python', 'install', $v.LiteLlm.Python); if ($r.Code -ne 0) { throw "uv python install failed: $($r.Output)" }
  if (-not (Test-Path $py)) { $r = Invoke-Native $Uv @('venv', $venv, '--python', $v.LiteLlm.Python); if ($r.Code -ne 0) { throw "uv venv failed: $($r.Output)" } }
  $r = Invoke-Native $Uv @('pip', 'install', '--python', $py, "litellm[proxy]==$($v.LiteLlm.Version)")
  if ($r.Code -ne 0) { throw "uv pip install failed: $($r.Output)" }
}

foreach ($m in $v.Models) {
  if ($SkipModel) { "  [skipped]  model $($m.File) (-SkipModel)"; continue }
  $modelPath = Join-Path $Root "models\$($m.File)"
  Step "model $($m.File) for $($m.Name) ($([math]::Round($m.Size / 1GB, 1)) GiB)" {
    (Test-Path $modelPath) -and ((Get-Item $modelPath).Length -eq $m.Size)
  } {
    New-Item -ItemType Directory -Force (Split-Path $modelPath) | Out-Null
    $part = "$modelPath.part"
    $r = Invoke-Native 'curl.exe' @('-fL', '--retry', '3', '-sS', '-C', '-', '-o', $part, $m.Url)
    if ($r.Code -ne 0) { throw "Model download failed: $($r.Output)" }
    $got = (Get-FileHash $part -Algorithm SHA256).Hash.ToLower()
    if ($got -ne $m.Sha256) { Remove-Item $part -Force; throw "Model SHA-256 mismatch for $($m.File) (expected $($m.Sha256), got $got)" }
    Move-Item $part $modelPath -Force
  }
}

# agent sandbox image (TASK-041): built locally from the repo, only when Docker Desktop is running
if ($dockerUp) {
  Step "sandbox image $($v.Sandbox.Image) (OpenClaw $($v.Sandbox.OpenClaw))" {
    # labels as JSON: PowerShell 5.1 drops the inner quotes of an {{index ... "name"}} template
    $labels = try { (Invoke-Native 'docker' @('image', 'inspect', '-f', '{{json .Config.Labels}}', $v.Sandbox.Image)).Output | ConvertFrom-Json } catch { $null }
    $labels -and $labels.'local-ai.openclaw' -eq $v.Sandbox.OpenClaw
  } {
    $r = Invoke-Native 'powershell.exe' @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'sandbox.ps1'), 'build')
    if ($r.Code -ne 0) { throw "sandbox image build failed: $($r.Output)" }
  }
} else { "  [skipped]  sandbox image (Docker Desktop not running)" }

''
if ($CheckOnly) {
  if ($missing) { "$missing item(s) missing; run without -CheckOnly to install."; exit 2 } else { 'Everything is in place.' }
} elseif ($changed) { "Installed $changed item(s). Next: scripts\init-secrets.ps1, then the stack scripts." }
else { 'Nothing to do: everything is already in place.' }
