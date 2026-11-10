# TASK-043 trial: one Google consent for a user's agent, on this PC (a Desktop OAuth client, loopback redirect,
# PKCE). Opens the browser, waits for Google to redirect back to a one-time listener on 127.0.0.1, exchanges the
# code and keeps the refresh token in Credential Manager only; nothing secret is printed.
# The scopes cover both trial routes (gog through the relay, workspace-mcp), so one consent serves both.
#
#   spike\task-043\google-consent.ps1 [-ClientJson <client_secret_*.json>] [-User owner] [-Account <gmail address>]
#
# Credential Manager: local-ai/google-client (the client JSON), local-ai/google-<user>-refresh (the refresh token).
param(
  [string]$ClientJson,
  [ValidatePattern('^[a-z][a-z0-9-]{0,30}$')][string]$User = 'owner',
  [string]$Account,
  [int]$TimeoutSec = 600
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\..\..\scripts\lib\secrets.ps1"

if (-not $ClientJson) {
  # the newest Desktop client in Downloads
  $ClientJson = Get-ChildItem (Join-Path $env:USERPROFILE 'Downloads\client_secret_*.json') | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
  if (-not $ClientJson) { throw 'No client_secret_*.json in Downloads: pass -ClientJson.' }
}
$client = (Get-Content $ClientJson -Raw | ConvertFrom-Json).installed
if (-not $client) { throw "$ClientJson is not a Desktop (installed) OAuth client." }
"Client: project $($client.project_id), $(Split-Path $ClientJson -Leaf)"

$scopes = @(
  'openid', 'https://www.googleapis.com/auth/userinfo.email', 'https://www.googleapis.com/auth/userinfo.profile',
  'https://www.googleapis.com/auth/gmail.modify', 'https://www.googleapis.com/auth/gmail.settings.basic',
  'https://www.googleapis.com/auth/calendar', 'https://www.googleapis.com/auth/drive',
  'https://www.googleapis.com/auth/documents', 'https://www.googleapis.com/auth/spreadsheets'
) -join ' '

function New-Random([int]$Bytes) {
  $b = New-Object byte[] $Bytes; [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b)
  [Convert]::ToBase64String($b).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}
$verifier = New-Random 48
$challenge = [Convert]::ToBase64String([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::ASCII.GetBytes($verifier))).TrimEnd('=').Replace('+', '-').Replace('/', '_')
$state = New-Random 24

$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$listener.Start()
$redirect = "http://127.0.0.1:$($listener.LocalEndpoint.Port)/"
$q = [ordered]@{
  client_id = $client.client_id; redirect_uri = $redirect; response_type = 'code'; scope = $scopes
  code_challenge = $challenge; code_challenge_method = 'S256'; state = $state; access_type = 'offline'; prompt = 'consent'
}
if ($Account) { $q.login_hint = $Account }
$url = 'https://accounts.google.com/o/oauth2/v2/auth?' + (($q.GetEnumerator() | ForEach-Object { "$($_.Key)=$([Uri]::EscapeDataString($_.Value))" }) -join '&')
"Opening the browser for the consent (or open this address on this PC):"
$url
Start-Process $url

try {
  $accept = $listener.AcceptTcpClientAsync()
  if (-not $accept.Wait($TimeoutSec * 1000)) { throw "No answer from the browser in $TimeoutSec s." }
  $conn = $accept.Result
  $stream = $conn.GetStream()
  $reader = New-Object IO.StreamReader($stream)
  $line = $reader.ReadLine()   # GET /?state=...&code=... HTTP/1.1
  $params = @{}
  if ($line -match '^GET /\?(\S*) HTTP') { foreach ($p in $Matches[1].Split('&')) { $k, $v = $p.Split('=', 2); $params[$k] = [Uri]::UnescapeDataString("$v".Replace('+', ' ')) } }
  $ok = $params.state -eq $state -and $params.code
  $msg = if ($ok) { 'Signed in. You can close this tab.' } else { "Not signed in: $($params.error)" }
  $body = [Text.Encoding]::UTF8.GetBytes("<!doctype html><meta charset=utf-8><title>Local AI</title><p style='font:16px system-ui;margin:2em'>$msg</p>")
  $head = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK`r`ncontent-type: text/html; charset=utf-8`r`ncontent-length: $($body.Length)`r`nconnection: close`r`n`r`n")
  $stream.Write($head, 0, $head.Length); $stream.Write($body, 0, $body.Length); $stream.Flush(); $conn.Close()
} finally { $listener.Stop() }
if ($params.state -ne $state) { throw 'The answer did not match this sign-in (state); nothing stored.' }
if (-not $params.code) { throw "Google did not sign in: $($params.error)" }

$tok = Invoke-RestMethod -Method Post 'https://oauth2.googleapis.com/token' -Body @{
  client_id = $client.client_id; client_secret = $client.client_secret; code = $params.code
  code_verifier = $verifier; redirect_uri = $redirect; grant_type = 'authorization_code'
}
if (-not $tok.refresh_token) { throw 'Google returned no refresh token; nothing stored.' }
$me = Invoke-RestMethod 'https://openidconnect.googleapis.com/v1/userinfo' -Headers @{ Authorization = "Bearer $($tok.access_token)" }

Set-LocalAiSecret ((Get-Content $ClientJson -Raw | ConvertFrom-Json) | ConvertTo-Json -Compress -Depth 5) 'local-ai/google-client'
Set-LocalAiSecret $tok.refresh_token "local-ai/google-$User-refresh"
Set-LocalAiSecret (@{ account = $me.email; scopes = $tok.scope; consented = (Get-Date).ToUniversalTime().ToString('o') } | ConvertTo-Json -Compress) "local-ai/google-$User-account"
''
"Signed in:  $($me.email)"
"Consented:  $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')) UTC"
"Scopes:     $(($tok.scope -split ' ' | ForEach-Object { $_ -replace '^https://www.googleapis.com/auth/', '' }) -join ', ')"
"Stored in Credential Manager: local-ai/google-client, local-ai/google-$User-refresh, local-ai/google-$User-account."
