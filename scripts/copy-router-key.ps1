# Copies the router key to the clipboard without printing it, for a client that cannot come in by its
# Tailscale login (the Mac setup needs no key since TASK-024). Clears the clipboard after 60 s
# (leave this window open until then). Windows clipboard history (Win+V), if enabled, may keep a copy:
# clear it afterwards.
# Usage: scripts\copy-router-key.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\secrets.ps1"

$key = Get-LocalAiRouterKey
Set-Clipboard -Value $key
'Router key copied. Paste it on the other device now; the clipboard is cleared in 60 s.'
Start-Sleep 60
if ((Get-Clipboard -Raw).Trim() -eq $key) { Set-Clipboard -Value ' ' }
'Clipboard cleared.'
