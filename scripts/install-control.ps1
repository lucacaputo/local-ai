# Installs the control service (TASK-025, TASK-026) so it can be reached when nobody is at the PC: a scheduled
# task runs scripts\start-control.ps1 at logon of this user and every 10 minutes after (start-control.ps1 does
# nothing while the service runs, so a crashed service is back within 10 minutes), and the /control route on
# tailnet port 4000 is published (tailscale serve keeps it across reboots). The AI stack itself is never started
# by any of this: only an up request to the service starts it. Needs no elevation; safe to run again.
#
#   scripts\install-control.ps1              register the task, start the service, publish /control
#   scripts\install-control.ps1 -Uninstall   stop the service, remove the task and the /control route
param([switch]$Uninstall)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\stack.ps1"
$taskName = 'local-ai-control'
$ts = Get-TailscaleExe
$tsUp = (Test-Path $ts) -and ((Invoke-Quiet $ts @('status')) -notmatch 'Logged out|stopped')

if ($Uninstall) {
  if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false; "Removed the scheduled task $taskName."
  } else { "No scheduled task $taskName." }
  & "$PSScriptRoot\start-control.ps1" -Stop
  if ($tsUp -and (Get-Serve4000).Paths -contains '/control') {
    Invoke-Quiet $ts @('serve', '--http', '4000', '--set-path', '/control', 'off') | Out-Null; 'Removed the /control route from the tailnet.'
  } else { 'No /control route on the tailnet.' }
  return
}

$start = Join-Path $PSScriptRoot 'start-control.ps1'
# conhost --headless: no console window at logon or on each repetition
$action = New-ScheduledTaskAction -Execute 'conhost.exe' -Argument "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$start`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$trigger.Repetition = (New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 10)).Repetition
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName $taskName -Description 'local-ai control service (TASK-026): runs scripts\start-control.ps1; never starts the AI stack itself' `
  -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
"Scheduled task ${taskName}: at logon of $env:USERNAME, then every 10 minutes."
& $start

if ($tsUp) {
  $serve = Get-Serve4000
  if ($serve.Mode -eq 'tcp') {
    # a TCP forward left by an ai-up from before TASK-023 blocks HTTP routes; a running router gets its "/" route back
    Invoke-Quiet $ts @('serve', '--tcp=4000', 'off') | Out-Null
    if (Test-Http 'http://127.0.0.1:4000/health/liveliness') { Invoke-Quiet $ts @('serve', '--bg', '--http', '4000', 'http://127.0.0.1:4000') | Out-Null }
    $serve = Get-Serve4000
  }
  if ($serve.Paths -notcontains '/control') { Invoke-Quiet $ts @('serve', '--bg', '--http', '4000', '--set-path', '/control', 'http://127.0.0.1:4100') | Out-Null }
  "Published on the tailnet: http://$(Get-TailnetName):4000/control"
} else { Write-Warning 'Tailscale is not signed in: /control is not published. Sign in and run this script again.' }
