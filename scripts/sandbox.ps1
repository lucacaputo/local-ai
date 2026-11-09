# One user's agent sandbox (TASK-041, TASK-042, decision-010/011/015): an OpenClaw container from the repo's image,
# with a named volume for its home folder (browser profile, files, OpenClaw state), on an internal Docker network
# of its own with no route out. Its gate (sandbox/gate) is the only other container there: the web proxy, the
# router pass, and the Control UI port, published on the host's loopback only; tailscale serve puts that on the
# tailnet over HTTPS. Secrets come from Credential Manager and reach the containers as environment variables,
# never on a command line or in a file; the router knows the sandbox's key only by its hash.
#
#   scripts\sandbox.ps1 build                  build the images (local-ai/sandbox, local-ai/sandbox-gate)
#   scripts\sandbox.ps1 start  [-User owner]   (re)create and start the gate and the sandbox; the volume is kept
#   scripts\sandbox.ps1 stop   [-User owner]   stop them and take the sandbox off the tailnet
#   scripts\sandbox.ps1 reset  [-User owner]   stop them and delete the volume: logins, files and history are gone
#   scripts\sandbox.ps1 status [-User owner]
#   scripts\sandbox.ps1 token  [-User owner]   copy the Control UI token to the clipboard (cleared after 60 s)
#   scripts\sandbox.ps1 revoke [-User owner]   the router stops taking this sandbox's key now; start issues a new one
#
# Needs Docker Desktop running; the router (scripts\ai-up.ps1) when the agent works.
param(
  [Parameter(Mandatory, Position = 0)][ValidateSet('build', 'start', 'stop', 'reset', 'status', 'token', 'revoke')][string]$Action,
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
$gateImage = 'local-ai/sandbox-gate'
$name = "openclaw-$User"
$gate = "openclaw-$User-gate"
$network = "openclaw-$User-net"
$volume = "openclaw-$User-home"
$tokenTarget = "local-ai/sandbox-$User-token"
$keyTarget = "local-ai/sandbox-$User-router"
$keysFile = Join-Path (Get-AiRoot) 'sandbox-keys.json'   # read by config\custom_auth.py (LOCAL_AI_SANDBOX_KEYS)
$ts = Get-TailscaleExe

function Invoke-Docker([string[]]$Arguments) {
  $out = Invoke-Quiet 'docker' $Arguments
  if ($LASTEXITCODE -ne 0) { throw "docker $($Arguments[0]) failed: $out" }
  $out
}
function Get-State([string]$Container = $name) { (Invoke-Quiet 'docker' @('inspect', '-f', '{{.State.Status}}', $Container)) -replace '\s', '' }
function Test-Image([string]$Image) { (Invoke-Quiet 'docker' @('image', 'inspect', '-f', '{{.Id}}', $Image)).StartsWith('sha256:') }
function New-Secret { $b = New-Object byte[] 32; [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b); ($b | ForEach-Object { $_.ToString('x2') }) -join '' }
function Get-Sha256([string]$Text) { (([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))) | ForEach-Object { $_.ToString('x2') }) -join '' }
# the router's list of sandbox keys, by hash: {"<user>": "<sha256 hex>"}; written whole, then swapped in
function Set-KeyHash([string]$Hash) {
  $keys = [ordered]@{}
  if (Test-Path $keysFile) { (Get-Content $keysFile -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $keys[$_.Name] = $_.Value } }
  if ($Hash) { $keys[$User] = $Hash } else { $keys.Remove($User) }
  $tmp = "$keysFile.tmp"
  [IO.File]::WriteAllText($tmp, (ConvertTo-Json $keys), (New-Object Text.UTF8Encoding $false))
  Move-Item $tmp $keysFile -Force
}
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
  foreach ($c in $name, $gate) { if ((Get-State $c) -match '^(running|exited|created|paused)$') { Invoke-Docker @('rm', '-f', $c) | Out-Null } }
  if (Test-Tailnet) { Invoke-Quiet $ts @('serve', "--https=$TailnetPort", 'off') | Out-Null }
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw 'Docker Desktop is not installed (README, Requirements).' }
if ((Invoke-Quiet 'docker' @('info', '--format', '{{.OSType}}')) -notmatch 'linux') { throw 'Docker Desktop is not running (or not in Linux containers mode).' }

switch ($Action) {
  'build' {
    $w = [Diagnostics.Stopwatch]::StartNew()
    Invoke-Docker @('build', '-q', '-t', $image, '-f', (Join-Path $repo 'sandbox\Dockerfile'), $repo) | Out-Null
    Invoke-Docker @('build', '-q', '-t', $gateImage, (Join-Path $repo 'sandbox\gate')) | Out-Null
    "Built $image and $gateImage in $([math]::Round($w.Elapsed.TotalSeconds)) s."
  }
  'start' {
    foreach ($i in $image, $gateImage) { if (-not (Test-Image $i)) { throw "No image $i yet: scripts\sandbox.ps1 build" } }
    if (-not (Get-LocalAiSecret $tokenTarget)) { Set-LocalAiSecret (New-Secret) $tokenTarget }
    if (-not (Get-LocalAiSecret $keyTarget)) { Set-LocalAiSecret (New-Secret) $keyTarget }
    Set-KeyHash (Get-Sha256 (Get-LocalAiSecret $keyTarget))   # the router reads the file again when it changes
    $origin = if (Test-Tailnet) { "https://$(Get-TailnetName):$TailnetPort" } else { "http://127.0.0.1:$Port" }
    Remove-Container   # recreated each time, so new secrets and images take effect; the volume keeps the state
    Invoke-Quiet 'docker' @('network', 'inspect', $network) | Out-Null
    if ($LASTEXITCODE -ne 0) {
      Invoke-Docker @('network', 'create', '--internal', '--label', "local-ai.user=$User", $network) | Out-Null
    }
    $hardening = @('--security-opt', 'no-new-privileges', '--cap-drop', 'ALL', '--label', "local-ai.user=$User")
    # The gate: on the default bridge (the internet, the host) and, as "gate", on the sandbox network
    Invoke-Docker (@('run', '-d', '--name', $gate, '--network', 'bridge', '-p', "127.0.0.1:${Port}:18789",
        '-e', "GATE_FORWARDS=18789=${name}:18789", '--read-only', '--memory', '128m', '--label', 'local-ai.gate=1') + $hardening + @($gateImage)) | Out-Null
    Invoke-Docker @('network', 'connect', '--alias', 'gate', $network, $gate) | Out-Null
    # tailscale serve's traffic reaches the gateway from the gate's address on the sandbox network, and the gate is
    # the sandbox's DNS (placeholder answers only)
    $nets = Invoke-Docker @('inspect', '-f', '{{json .NetworkSettings.Networks}}', $gate) | ConvertFrom-Json
    # docker run -e NAME (no value) copies the value from this process, so no secret appears in a command line
    $env:OPENCLAW_GATEWAY_TOKEN = Get-LocalAiSecret $tokenTarget
    $env:LOCAL_AI_SANDBOX_KEY = Get-LocalAiSecret $keyTarget
    $env:OPENCLAW_PUBLIC_ORIGIN = $origin
    $env:OPENCLAW_TRUSTED_PROXY = $nets.$network.IPAddress
    try {
      Invoke-Docker (@(
        'run', '-d', '--name', $name, '--hostname', 'sandbox', '--network', $network, '--dns', $nets.$network.IPAddress,
        '--mount', "type=volume,src=$volume,dst=/home/node",
        '--memory', $Memory, '--shm-size', '1g',
        '-e', 'OPENCLAW_GATEWAY_TOKEN', '-e', 'LOCAL_AI_SANDBOX_KEY', '-e', 'OPENCLAW_PUBLIC_ORIGIN', '-e', 'OPENCLAW_TRUSTED_PROXY', '-e', 'TZ=Europe/Rome',
        '--label', 'local-ai.sandbox=1') + $hardening + @($image)) | Out-Null
    } finally { Remove-Item Env:OPENCLAW_GATEWAY_TOKEN, Env:LOCAL_AI_SANDBOX_KEY, Env:OPENCLAW_PUBLIC_ORIGIN, Env:OPENCLAW_TRUSTED_PROXY -ErrorAction SilentlyContinue }
    $ok = $false
    for ($i = 0; $i -lt 60 -and -not $ok; $i++) { Start-Sleep 1; $ok = Test-Http "http://127.0.0.1:$Port/readyz" }
    if (-not $ok) { throw "Gateway not ready after 60 s: docker logs $name; docker logs $gate" }
    if ((Test-Tailnet) -and -not (Publish-Tailnet)) { $origin = "http://127.0.0.1:$Port (on this PC only)" }
    "Sandbox $name is up: $origin (token: scripts\sandbox.ps1 token -User $User)."
  }
  'stop' {
    if (Test-Tailnet) { Invoke-Quiet $ts @('serve', "--https=$TailnetPort", 'off') | Out-Null }
    if ((Get-State) -eq 'running') { Invoke-Docker @('stop', $name) | Out-Null; "Stopped $name; its volume $volume is kept." } else { "$name is not running." }
    if ((Get-State $gate) -eq 'running') { Invoke-Docker @('stop', $gate) | Out-Null }
  }
  'reset' {
    Remove-Container
    if ((Invoke-Quiet 'docker' @('volume', 'ls', '-q', '--filter', "name=^$volume$")) -match $volume) { Invoke-Docker @('volume', 'rm', $volume) | Out-Null }
    "Reset $name`: containers and volume $volume deleted (the network and the router key are kept)."
  }
  'status' {
    $state = Get-State
    if (-not $state -or $state -match 'Error') { "$name does not exist." } else {
      $origin = Invoke-Quiet 'docker' @('inspect', '-f', '{{range .Config.Env}}{{println .}}{{end}}', $name) | Select-String '^OPENCLAW_PUBLIC_ORIGIN=(.*)' | ForEach-Object { $_.Matches[0].Groups[1].Value }
      "$name`: $state, $origin, volume $volume, image $((Invoke-Quiet 'docker' @('inspect', '-f', '{{.Image}}', $name)).Substring(7, 12)); gate $gate`: $(Get-State $gate)"
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
  'revoke' {
    Set-KeyHash $null
    Remove-LocalAiSecret $keyTarget
    "The router no longer takes $User's sandbox key; other sandboxes and clients are untouched. scripts\sandbox.ps1 start -User $User issues a new one."
  }
}
