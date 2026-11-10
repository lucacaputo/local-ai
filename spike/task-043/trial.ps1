# TASK-043 trial: both Google routes on a user's sandbox, with the account signed in by google-consent.ps1.
#   (a) gog 0.47.0 in the sandbox, its Google API calls sent to the relay ("google", relay.ts), which holds the token
#   (b) workspace-mcp 2.2.0 in its own container ("gws"), an MCP server for OpenClaw
# Both sit on the sandbox network only and reach Google through the gate; the sandbox reaches them through the gate
# too (GATE_SERVICES). The sandbox gets gog and the trial config by copying into the running container, so
# scripts\sandbox.ps1 start (or -Stop here) puts the image's own back.
#
#   spike\task-043\trial.ps1 [-User owner]          set up and start the trial
#   spike\task-043\trial.ps1 [-User owner] -Stop    remove the trial containers and restart the sandbox plain
param(
  [ValidatePattern('^[a-z][a-z0-9-]{0,30}$')][string]$User = 'owner',
  [switch]$Stop
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\..\..\scripts\lib\secrets.ps1"
. "$PSScriptRoot\..\..\scripts\lib\stack.ps1"
$repo = Resolve-Path "$PSScriptRoot\..\.."
$name = "openclaw-$User"
$network = "openclaw-$User-net"
$relay = "openclaw-$User-google"; $relayVol = "openclaw-$User-google"
$gws = "openclaw-$User-gws"; $gwsVol = "openclaw-$User-gws"
$gwsImage = 'local-ai/workspace-mcp:2.2.0'
$gogVersion = '0.47.0'
$gogSha256 = 'c3ed94efca90c754cdda300e3c7f8cc2f3d7df86d3fdc5d11f996c7518a09c24'   # gogcli_0.47.0_linux_amd64.tar.gz, release checksums.txt
$hardening = @('--security-opt', 'no-new-privileges', '--cap-drop', 'ALL', '--label', "local-ai.user=$User", '--label', 'local-ai.trial=task-043')

function Invoke-Docker([string[]]$Arguments) {
  $out = Invoke-Quiet 'docker' $Arguments
  if ($LASTEXITCODE -ne 0) { throw "docker $($Arguments[0]) failed: $out" }
  $out
}
function Remove-Trial { foreach ($c in $relay, $gws) { Invoke-Quiet 'docker' @('rm', '-f', $c) | Out-Null } }
# a file into a volume, from stdin (secrets never on a command line), owned by the container user that reads it
function Write-VolumeFile([string]$Volume, [string]$Path, [string]$Content, [int]$Uid) {
  $dir = Split-Path $Path -Parent
  $script = "umask 077; mkdir -p /v/$dir && cat > /v/$Path && chown -R ${Uid}:${Uid} /v"
  $Content | docker run --rm -i --network none --user 0 --mount "type=volume,src=$Volume,dst=/v" --entrypoint sh local-ai/sandbox-gate -c $script
  if ($LASTEXITCODE -ne 0) { throw "could not write $Path into $Volume" }
}

if ($Stop) {
  Remove-Trial
  & "$repo\scripts\sandbox.ps1" start -User $User
  "Trial stopped; $name runs its image's own config again (volumes $relayVol and $gwsVol kept: docker volume rm to forget the sign-in there)."
  return
}

$clientJson = Get-LocalAiSecret 'local-ai/google-client'
$refresh = Get-LocalAiSecret "local-ai/google-$User-refresh"
$acct = Get-LocalAiSecret "local-ai/google-$User-account"
if (-not ($clientJson -and $refresh -and $acct)) { throw "No Google sign-in for $User yet: spike\task-043\google-consent.ps1 -User $User" }
$client = ($clientJson | ConvertFrom-Json).installed
$acct = $acct | ConvertFrom-Json

# images: the gate (with GATE_SERVICES) and workspace-mcp
& "$repo\scripts\sandbox.ps1" build
Invoke-Docker @('build', '-q', '-t', $gwsImage, (Join-Path $repo 'spike\task-043\workspace-mcp')) | Out-Null

# gog, checked against the release's checksum
$gogDir = Join-Path $env:TEMP "gogcli-$gogVersion"
$tgz = Join-Path $gogDir "gogcli_${gogVersion}_linux_amd64.tar.gz"
if (-not (Test-Path "$gogDir\gog")) {
  New-Item -ItemType Directory -Force $gogDir | Out-Null
  Invoke-WebRequest "https://github.com/openclaw/gogcli/releases/download/v$gogVersion/gogcli_${gogVersion}_linux_amd64.tar.gz" -OutFile $tgz -UseBasicParsing
  if ((Get-FileHash $tgz -Algorithm SHA256).Hash -ne $gogSha256) { Remove-Item $tgz; throw 'gog download does not match its checksum.' }
  tar -xzf $tgz -C $gogDir gog
  if ($LASTEXITCODE -ne 0) { throw 'could not unpack gog' }
}

# the sandbox and its gate, the gate letting the sandbox reach the two services
Remove-Trial
& "$repo\scripts\sandbox.ps1" start -User $User -Services 'google:8080', 'gws:8000'

# secrets into the services' volumes: the relay gets the refresh token; workspace-mcp gets the same sign-in in its
# own credential format, so the one consent serves both routes
Write-VolumeFile $relayVol 'relay.json' (@{ client_id = $client.client_id; client_secret = $client.client_secret; refresh_token = $refresh } | ConvertTo-Json -Compress) 1000
Write-VolumeFile $gwsVol 'client_secret.json' $clientJson 10001
Write-VolumeFile $gwsVol "creds/$($acct.account).json" (@{
    token = $null; refresh_token = $refresh; token_uri = 'https://oauth2.googleapis.com/token'
    client_id = $client.client_id; client_secret = $client.client_secret; scopes = @($acct.scopes -split ' '); expiry = $null
  } | ConvertTo-Json -Compress) 10001

Invoke-Docker (@('run', '-d', '--name', $relay, '--network', $network, '--network-alias', 'google', '--read-only', '--memory', '128m',
    '--mount', "type=bind,src=$repo\spike\task-043\relay.ts,dst=/relay/relay.ts,readonly",
    '--mount', "type=volume,src=$relayVol,dst=/secrets,readonly") + $hardening + @('local-ai/sandbox-gate', 'node', '/relay/relay.ts')) | Out-Null
Invoke-Docker (@('run', '-d', '--name', $gws, '--network', $network, '--network-alias', 'gws', '--read-only', '--tmpfs', '/tmp', '--memory', '1g',
    '--mount', "type=volume,src=$gwsVol,dst=/data", '-e', "USER_GOOGLE_EMAIL=$($acct.account)") + $hardening + @($gwsImage)) | Out-Null

# gog into the sandbox: the real binary out of the agent's reach, and a wrapper that sends it to the relay
$wrapper = "#!/bin/sh`n# TASK-043 trial: gog's Google API calls go to the relay, which holds the token; the sandbox has none`nexport GOG_GOOGLE_API_BASE_URL=http://google:8080`nexport GOG_ACCOUNT=$($acct.account)`nexec /usr/local/lib/gogcli/gog `"`$@`"`n"
$tmpWrapper = Join-Path $env:TEMP 'gog-wrapper.sh'
[IO.File]::WriteAllText($tmpWrapper, $wrapper, (New-Object Text.UTF8Encoding $false))
Invoke-Docker @('exec', '-u', '0', $name, 'mkdir', '-p', '/usr/local/lib/gogcli') | Out-Null
Invoke-Docker @('cp', "$gogDir\gog", "${name}:/usr/local/lib/gogcli/gog") | Out-Null
Invoke-Docker @('cp', $tmpWrapper, "${name}:/usr/local/bin/gog") | Out-Null
Invoke-Docker @('cp', (Join-Path $repo 'spike\task-043\openclaw.trial.json5'), "${name}:/etc/openclaw/openclaw.json5") | Out-Null
Invoke-Docker @('exec', '-u', '0', $name, 'sh', '-c', 'chmod 0755 /usr/local/lib/gogcli/gog /usr/local/bin/gog && chmod 0444 /etc/openclaw/openclaw.json5') | Out-Null
Invoke-Docker @('restart', $name) | Out-Null

$ok = $false
for ($i = 0; $i -lt 90 -and -not $ok; $i++) { Start-Sleep 1; $ok = Test-Http 'http://127.0.0.1:18789/readyz' }
if (-not $ok) { throw "Gateway not ready after 90 s: docker logs $name" }
"Trial up for $($acct.account) (consented $($acct.consented)): gog -> relay $relay, MCP $gws. Logs: docker logs $relay; docker logs $gws"
