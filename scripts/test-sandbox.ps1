# Checks a running sandbox's network and router limits (TASK-042): what it must reach and what it must not.
# Probes run inside the container (as the agent would), plus a few from this PC; every line says what was expected.
#
#   scripts\test-sandbox.ps1 [-User owner] [-Revoke]
#     -Revoke  also revoke the sandbox's key, check the sandbox is refused and the owner's key is not, then start the
#              sandbox again (it gets a new key; the container is recreated, the volume kept)
#
# Needs the stack (scripts\ai-up.ps1) and the sandbox (scripts\sandbox.ps1 start) running. Exits 1 on any failure.
param(
  [ValidatePattern('^[a-z][a-z0-9-]{0,30}$')][string]$User = 'owner',
  [switch]$Revoke
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\secrets.ps1"
. "$PSScriptRoot\lib\stack.ps1"
$name = "openclaw-$User"
$failed = 0

function Check([string]$What, [string]$Got, [string]$Want) {
  $ok = $Got -match $Want
  if (-not $ok) { $script:failed++ }
  "{0} {1,-52} {2,-5} (want {3})" -f $(if ($ok) { 'ok  ' } else { 'FAIL' }), $What, $Got, ($Want -replace '[\^\$]', '')
}

# The probes go to the container on stdin, so no quoting passes through PowerShell's native argument handling
# (PowerShell ends piped text with CRLF; the container drops the CRs).
# Each prints "<id> <HTTP status>" (000: no connection at all); dns prints the addresses the sandbox resolves.
$probes = @'
p() { id=$1; shift; printf '%s %s\n' "$id" "$(curl -s -o /dev/null -m 30 -w '%{http_code}' "$@")"; }
chat() { printf '{"model":"%s","max_tokens":5,"messages":[{"role":"user","content":"Say OK."}]}' "$1"; }
K="Authorization: Bearer $LOCAL_AI_SANDBOX_KEY"
J="content-type: application/json"
p web            https://example.com/
p web-direct     --noproxy '*' https://example.com/
p router-direct  --noproxy '*' http://host.docker.internal:4000/v1/models
p llama-swap     http://host.docker.internal:8080/health
p control        http://host.docker.internal:4100/
p router-addr    http://host.docker.internal:4000/v1/models
p lan            http://192.168.1.1/
p lan-direct     --noproxy '*' http://192.168.1.1/
p metadata       http://169.254.169.254/
p loopback       --noproxy '' -x http://gate:3128 http://127.0.0.1:18789/
p no-key         http://gate:4000/v1/models
p spoofed-login  -H "Tailscale-User-Login: $SPOOF" http://gate:4000/v1/models
p key-models     -H "$K" http://gate:4000/v1/models
p key-local      -H "$K" -H "$J" -d "$(chat local-coder-vision)" http://gate:4000/v1/chat/completions
p key-claude     -H "$K" -H "$J" -d "$(chat anthropic/claude-haiku-4-5)" http://gate:4000/v1/chat/completions
p key-messages   -H "$K" -H "$J" -d "$(chat claude-haiku-4-5)" http://gate:4000/v1/messages
p key-admin      -H "$K" http://gate:4000/key/generate
printf 'dns %s\n' "$(getent hosts example.com | cut -d' ' -f1 | tr '\n' ',' | sed 's/,$//')"
'@
$expect = [ordered]@{
  'web'             = @('^200$', 'internet, through the gate')
  'web-direct'      = @('^000$', 'internet, around the gate')
  'router-direct'   = @('^000$', 'router, around the gate')
  'llama-swap'      = @('^403$', 'llama-swap (PC port 8080)')
  'control'         = @('^403$', 'control service (PC port 4100)')
  'router-addr'     = @('^403$', 'router by its PC address, through the proxy')
  'lan'             = @('^403$', 'LAN address, through the gate')
  'lan-direct'      = @('^000$', 'LAN address, around the gate')
  'metadata'        = @('^403$', 'link-local metadata address')
  'loopback'        = @('^403$', 'the container''s loopback, sent to the gate (the browser)')
  'no-key'          = @('^401$', 'router pass, no key')
  'spoofed-login'   = @('^401$', 'router pass, owner''s Tailscale login spoofed')
  'key-models'      = @('^200$', 'sandbox key: list models')
  'key-local'       = @('^200$', 'sandbox key: local model answers')
  'key-claude'      = @('^403$', 'sandbox key: Claude model')
  'key-messages'    = @('^403$', 'sandbox key: Anthropic messages route')
  'key-admin'       = @('^403$', 'sandbox key: admin route (gate refuses non-/v1/)')
  'dns'             = @('^198\.18\.0\.1$', 'sandbox DNS: the placeholder only')
}

function Invoke-Sh([string]$Script) { $Script | docker exec -i -e SPOOF $name sh -c "tr -d '\r' | sh" 2>&1 }
function Invoke-Probes {
  $env:SPOOF = (Get-AllowedLogins (Get-AiRoot) | Select-Object -First 1)
  if (-not $env:SPOOF) { $env:SPOOF = 'owner@example.com' }
  try { $out = Invoke-Sh $probes } finally { Remove-Item Env:SPOOF -ErrorAction SilentlyContinue }
  $got = @{}
  foreach ($l in $out) { if ("$l" -match '^(\S+) (\S+)$') { $got[$Matches[1]] = $Matches[2] } }
  $got
}
function Get-RouterStatus([hashtable]$Headers) {
  try { (Invoke-WebRequest 'http://127.0.0.1:4000/v1/models' -Headers $Headers -UseBasicParsing -TimeoutSec 15).StatusCode } catch { [int]$_.Exception.Response.StatusCode }
}
function Get-SandboxKeyStatus {
  "$(Invoke-Sh 'curl -s -o /dev/null -m 30 -w "%{http_code}" -H "Authorization: Bearer $LOCAL_AI_SANDBOX_KEY" http://gate:4000/v1/models')".Trim()
}

if ((Invoke-Quiet 'docker' @('inspect', '-f', '{{.State.Status}}', $name)) -notmatch 'running') { throw "$name is not running: scripts\sandbox.ps1 start -User $User" }
"From inside $name"
$got = Invoke-Probes
foreach ($e in $expect.GetEnumerator()) { Check $e.Value[1] ($(if ($got[$e.Key]) { $got[$e.Key] } else { '-' })) $e.Value[0] }

''
'From this PC'
$routerKey = Get-LocalAiRouterKey
Check "owner's router key" (Get-RouterStatus @{ 'x-litellm-api-key' = $routerKey }) '^200$'
Check "owner's router key on a request marked as a sandbox's" (Get-RouterStatus @{ 'x-litellm-api-key' = $routerKey; 'x-local-ai-sandbox' = '1' }) '^401$'
$keysFile = Join-Path (Get-AiRoot) 'sandbox-keys.json'
$sandboxKey = Get-LocalAiSecret "local-ai/sandbox-$User-router"
Check 'key file holds the hash, not the key' $(if ((Get-Content $keysFile -Raw).Contains($sandboxKey)) { 'key' } else { 'hash' }) '^hash$'
Check 'docker port of the sandbox (none: the gate forwards)' $(if ((Invoke-Quiet 'docker' @('port', $name)).Trim()) { 'some' } else { 'none' }) '^none$'

# no secret in any log: the router's, the gate's, OpenClaw's (read shared: the running processes hold them open)
function Read-Shared([string]$Path) { $fs = [IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite'); try { (New-Object IO.StreamReader $fs).ReadToEnd() } finally { $fs.Close() } }
$secrets = @($routerKey, $sandboxKey, (Get-LocalAiSecret "local-ai/sandbox-$User-token")) | Where-Object { $_ }
$logs = @(Get-ChildItem (Join-Path (Get-AiRoot) 'logs\*.log') | ForEach-Object { Read-Shared $_.FullName })
$logs += (Invoke-Quiet 'docker' @('logs', "openclaw-$User-gate")), (Invoke-Quiet 'docker' @('logs', $name)), (Invoke-Quiet 'docker' @('exec', $name, 'sh', '-c', 'cat /tmp/openclaw/*.log'))
$leaks = @($logs | Where-Object { $t = $_; $secrets | Where-Object { $t.Contains($_) } }).Count
Check 'logs that contain a key or the token' "$leaks" '^0$'

if ($Revoke) {
  ''
  'Revoke'
  & "$PSScriptRoot\sandbox.ps1" revoke -User $User | Out-Null
  Check 'sandbox key after revoke' (Get-SandboxKeyStatus) '^401$'
  Check "owner's router key after revoke" (Get-RouterStatus @{ 'x-litellm-api-key' = $routerKey }) '^200$'
  & "$PSScriptRoot\sandbox.ps1" start -User $User | Out-Null
  Check 'new sandbox key after start' (Get-SandboxKeyStatus) '^200$'
}

''
if ($failed) { "$failed check(s) failed."; exit 1 } else { 'All checks passed.' }
