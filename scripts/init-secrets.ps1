# Creates the router key in Windows Credential Manager if it does not exist yet.
# The key is generated in memory, stored, and never printed or written to a file.
# Usage: scripts\init-secrets.ps1 [-Rotate]
param([switch]$Rotate)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\secrets.ps1"

if ((Get-LocalAiSecret) -and -not $Rotate) {
  'Router key already stored. Use -Rotate to replace it (clients must then pick up the new key).'
  return
}
$bytes = New-Object byte[] 24
[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
Set-LocalAiSecret ('sk-local-' + (($bytes | ForEach-Object { $_.ToString('x2') }) -join ''))
if ((Get-LocalAiSecret).Length -ne 57) { throw 'Stored key did not read back correctly.' }
if ($Rotate) { 'Router key rotated and stored in Credential Manager.' } else { 'Router key created and stored in Credential Manager.' }
