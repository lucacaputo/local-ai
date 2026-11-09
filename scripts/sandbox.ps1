# One user's agent sandbox (TASK-041, decision-010/011): an OpenClaw container from the repo's image, with a named
# volume for its home folder (browser profile, files, OpenClaw state). The gateway is published on the host's
# loopback only, and tailscale serve puts it on the tailnet over HTTPS. Secrets come from Credential Manager and
# reach the container as environment variables, never on a command line or in a file.
#
#   scripts\sandbox.ps1 build                  build the image (local-ai/sandbox)
#   scripts\sandbox.ps1 start  [-User owner]   (re)create and start the container; the volume is kept
#   scripts\sandbox.ps1 stop   [-User owner]   stop it and take it off the tailnet
#   scripts\sandbox.ps1 reset  [-User owner]   stop it and delete its volume: logins, files and history are gone
#   scripts\sandbox.ps1 status [-User owner]
#   scripts\sandbox.ps1 token  [-User owner]   copy the Control UI token to the clipboard (cleared after 60 s)
#
# Needs Docker Desktop running; the router (scripts\ai-up.ps1) when the agent works.
param(
  [Parameter(Mandatory, Position = 0)][ValidateSet('build', 'start', 'stop', 'reset', 'status', 'token')][string]$Action,
  [ValidatePattern('^[a-z][a-z0-9-]{0,30}$')][string]$User = 'owner',
  [int]$Port = 18789,            # host loopback port of this user's gateway
  [int]$TailnetPort = 8443,      # HTTPS port on the tailnet
  [string]$Memory = '4g'
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\secrets.ps1"
. "$PSScriptRoot\lib\stack.ps1"
$repo = Split-Path $PSScriptRoot -Parent
$image = 'local-ai/sandbox'
$name = "openclaw-$User"
$volume = "openclaw-$User-home"
$tokenTarget = "local-ai/sandbox-$User-token"
$ts = Get-TailscaleExe

function Invoke-Docker([string[]]$Arguments) {
  $out = Invoke-Quiet 'docker' $Arguments
  if ($LASTEXITCODE -ne 0) { throw "docker $($Arguments[0]) failed: $out" }
  $out
}
function Get-State { (Invoke-Quiet 'docker' @('inspect', '-f', '{{.State.Status}}', $name)) -replace '\s', '' }
function Test-Tailnet { (Test-Path $ts) -and ((Invoke-Quiet $ts @('status')) -notmatch 'Logged out|stopped') }
# tailscale serve waits forever when HTTPS is not enabled on the tailnet; give up after 15 s and show its message.
function Publish-Tailnet {
  $out = Join-Path $env:TEMP "sandbox-serve-$User.txt"
  $p = Start-Process $ts -ArgumentList 'serve', '--bg', "--https=$TailnetPort", "http://127.0.0.1:$Port" -RedirectStandardOutput $out -RedirectStandardError "$out.err" -WindowStyle Hidden -PassThru
  if (-not $p.WaitForExit(15000)) {
    $p | Stop-Process -Force
    Write-Warning "Not published on the tailnet: $((Get-Content $out, "$out.err" -Raw -ErrorAction SilentlyContinue) -join ' ')"
    return $false
  }
  $true
}
function Remove-Container {
  if ((Get-State) -match '^(running|exited|created|paused)$') { Invoke-Docker @('rm', '-f', $name) | Out-Null }
  if (Test-Tailnet) { Invoke-Quiet $ts @('serve', "--https=$TailnetPort", 'off') | Out-Null }
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw 'Docker Desktop is not installed (README, Requirements).' }
if ((Invoke-Quiet 'docker' @('info', '--format', '{{.OSType}}')) -notmatch 'linux') { throw 'Docker Desktop is not running (or not in Linux containers mode).' }

switch ($Action) {
  'build' {
    $w = [Diagnostics.Stopwatch]::StartNew()
    Invoke-Docker @('build', '-q', '-t', $image, '-f', (Join-Path $repo 'sandbox\Dockerfile'), $repo) | Out-Null
    "Built $image in $([math]::Round($w.Elapsed.TotalSeconds)) s."
  }
  'start' {
    if (-not (Invoke-Quiet 'docker' @('image', 'inspect', '-f', '{{.Id}}', $image)).StartsWith('sha256:')) { throw "No image $image yet: scripts\sandbox.ps1 build" }
    if (-not (Get-LocalAiSecret $tokenTarget)) {
      $bytes = New-Object byte[] 24
      [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
      Set-LocalAiSecret (($bytes | ForEach-Object { $_.ToString('x2') }) -join '') $tokenTarget
    }
    $origin = if (Test-Tailnet) { "https://$(Get-TailnetName):$TailnetPort" } else { "http://127.0.0.1:$Port" }
    Remove-Container   # recreated each time, so new secrets and image take effect; the volume keeps the state
    # docker run -e NAME (no value) copies the value from this process, so no secret appears in a command line
    $env:OPENCLAW_GATEWAY_TOKEN = Get-LocalAiSecret $tokenTarget
    $env:LOCAL_AI_ROUTER_KEY = Get-LocalAiRouterKey   # until TASK-042 gives each sandbox its own credential
    $env:OPENCLAW_PUBLIC_ORIGIN = $origin
    # the default bridge's gateway, where Docker Desktop's published port delivers (and so tailscale serve's) traffic
    $env:OPENCLAW_TRUSTED_PROXY = (Invoke-Docker @('network', 'inspect', 'bridge', '-f', '{{(index .IPAM.Config 0).Gateway}}')).Trim()
    try {
      Invoke-Docker @(
        'run', '-d', '--name', $name, '--hostname', 'sandbox',
        '--mount', "type=volume,src=$volume,dst=/home/node",
        '-p', "127.0.0.1:${Port}:18789",
        '--memory', $Memory, '--shm-size', '1g',
        '--security-opt', 'no-new-privileges', '--cap-drop', 'ALL',
        '-e', 'OPENCLAW_GATEWAY_TOKEN', '-e', 'LOCAL_AI_ROUTER_KEY', '-e', 'OPENCLAW_PUBLIC_ORIGIN', '-e', 'OPENCLAW_TRUSTED_PROXY', '-e', 'TZ=Europe/Rome',
        '--label', 'local-ai.sandbox=1', '--label', "local-ai.user=$User",
        $image) | Out-Null
    } finally { Remove-Item Env:OPENCLAW_GATEWAY_TOKEN, Env:LOCAL_AI_ROUTER_KEY, Env:OPENCLAW_PUBLIC_ORIGIN, Env:OPENCLAW_TRUSTED_PROXY -ErrorAction SilentlyContinue }
    $ok = $false
    for ($i = 0; $i -lt 60 -and -not $ok; $i++) { Start-Sleep 1; $ok = Test-Http "http://127.0.0.1:$Port/readyz" }
    if (-not $ok) { throw "Gateway not ready after 60 s: docker logs $name" }
    if ((Test-Tailnet) -and -not (Publish-Tailnet)) { $origin = "http://127.0.0.1:$Port (on this PC only)" }
    "Sandbox $name is up: $origin (token: scripts\sandbox.ps1 token -User $User)."
  }
  'stop' {
    if (Test-Tailnet) { Invoke-Quiet $ts @('serve', "--https=$TailnetPort", 'off') | Out-Null }
    if ((Get-State) -eq 'running') { Invoke-Docker @('stop', $name) | Out-Null; "Stopped $name; its volume $volume is kept." } else { "$name is not running." }
  }
  'reset' {
    Remove-Container
    if ((Invoke-Quiet 'docker' @('volume', 'ls', '-q', '--filter', "name=^$volume$")) -match $volume) { Invoke-Docker @('volume', 'rm', $volume) | Out-Null }
    "Reset $name`: container and volume $volume deleted."
  }
  'status' {
    $state = Get-State
    if (-not $state -or $state -match 'Error') { "$name does not exist." } else {
      $origin = Invoke-Quiet 'docker' @('inspect', '-f', '{{range .Config.Env}}{{println .}}{{end}}', $name) | Select-String '^OPENCLAW_PUBLIC_ORIGIN=(.*)' | ForEach-Object { $_.Matches[0].Groups[1].Value }
      "$name`: $state, $origin, volume $volume, image $((Invoke-Quiet 'docker' @('inspect', '-f', '{{.Image}}', $name)).Substring(7, 12))"
    }
  }
  'token' {
    $t = Get-LocalAiSecret $tokenTarget
    if (-not $t) { throw "No token for $User yet: scripts\sandbox.ps1 start -User $User" }
    Set-Clipboard -Value $t
    'Token copied. Paste it in the Control UI now; the clipboard is cleared in 60 s.'
    Start-Sleep 60
    if ((Get-Clipboard -Raw).Trim() -eq $t) { Set-Clipboard -Value ' ' }
    'Clipboard cleared.'
  }
}
