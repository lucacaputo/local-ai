---
id: TASK-026
title: Start the control service at logon
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 14:31'
updated_date: '2026-10-19 21:47'
labels: []
milestone: m-3
dependencies:
  - TASK-025
references:
  - scripts/install.ps1
priority: medium
ordinal: 26000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The control service must already be running when the user is away. It runs as the user, because ai-up reads the router key from the user Credential Manager, so it starts at logon rather than as a Windows service. The PC has to be on with the user logged in; Wake-on-LAN is out of scope. The Tailscale ACL today only grants tcp:4000 to the user own devices (TASK-013).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 An install script registers the control service to start at logon and publishes its port on the tailnet; an uninstall script removes both; running either twice is safe
- [x] #2 After the user logs off and on again, the service answers status from the Mac while the AI stack stays down until up is called
- [x] #3 The control service is reachable from the Mac through the existing tcp:4000 ACL grant (one port, /control route, TASK-022), so no ACL change is needed; checked and recorded
- [x] #4 install.ps1 -CheckOnly or the README tells whether the control service is installed
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Research (done): a scheduled task with an at-logon trigger and a 10-minute repetition can be registered without elevation. Check that the detached service survives the task finishing and that conhost --headless avoids a console window.
2. scripts/install-control.ps1 [-Uninstall]: registers the scheduled task local-ai-control (at logon of this user, repeated every 10 minutes, runs start-control.ps1, which is a no-op when the service already runs, so a crashed service comes back), starts it once, and publishes /control on tailnet port 4000 (tailscale serve keeps it across reboots). -Uninstall stops the service, removes the task and the /control route. Both safe to run twice. The AI stack is never started by any of this.
3. install.ps1 -CheckOnly reports the control service (installed, running, /control published) without failing.
4. Tests: install twice, uninstall twice; the task runs and the service answers through the tailnet; the repetition restarts a killed service; the stack stays down; user logs off and on, then checks status from the Mac; ACL: the Mac reaches /control through the existing tcp:4000 grant.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Built scripts/install-control.ps1 [-Uninstall] and the install.ps1 report line. Probe: a scheduled task created without elevation (at-logon trigger, PT10M repetition, indefinite) runs conhost --headless powershell start-control.ps1; the service keeps running after the task finishes and after Stop-ScheduledTask, and no window opens. Tests: install twice (second: already running), task state Ready with the logon trigger for CAPS\caput and repetition PT10M for an indefinite duration; /control published and /control/status answers through the tailnet; the stack stays down; killed service brought back by a task run; uninstall twice (second: nothing to remove); install.ps1 -CheckOnly shows not installed / installed, running, /control published. Reinstalled; state before the logoff test: task registered, service running (pid 26772), /control published, stack down. Pending: user logs off and on (ends this Claude Code session; resume with claude --continue), then checks status from the Mac; afterwards kill the service and wait for the 10-minute repetition to bring it back (the repetition only starts after a logon).

First logoff/logon test (user, 23:27): the task ran at logon (23:27:14) and the service started 3 s later with 0 allowed logins, because Tailscale was not signed in yet; the Mac got 401. The 10-minute repetition cannot fix that (the service is running). Fix: control-service.py re-reads the allowlist on demand through Get-AllowedLogins (every 60 s, every 5 s while empty, at once on the first request when it started empty), so a changed allowed-logins.txt also applies without a restart; the 401 answer says when the PC has no allowed logins; start-litellm.ps1 warns when the router starts with an empty allowlist. Simulated (service started with an empty allowlist): first request 200, ALLOWLIST logged; allowed-logins.txt without the login: 401 within 35 s, removed: 200 within 65 s; router warning shown with an empty allowed-logins.txt. State before the second logoff test: task registered, service started by the task, /control published, stack down, no allowed-logins.txt.

Second logoff/logon test (user, 23:36): logon 23:36:17, task ran at once, service START 23:36:19 with 0 allowed logins (Tailscale again not ready); the first request from the Mac at 23:37:17 re-read the allowlist (1 login) and got 200; up from the Mac: Stack healthy in 14.3 s; down: stopped. So the service answers after a fresh logon and the stack stays down until up. ACL: the Mac reached /control through the existing tcp:4000 grant (one port, path route), no change needed.

Repetition test: killed the service at 23:39:28; the task's 10-minute repetition (23:46:17, counted from the 23:36:17 logon) brought it back at 23:46:18 with 1 allowed login. Recorded in doc-002.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
scripts/install-control.ps1 [-Uninstall] registers the scheduled task local-ai-control (no elevation; at logon of the user plus a 10-minute repetition; conhost --headless runs start-control.ps1, which does nothing while the service runs), starts the service, and publishes /control on tailnet port 4000. -Uninstall removes the task, the service and the route; both are safe to run twice and never start the AI stack. install.ps1 -CheckOnly reports the control service. Logon race found and fixed: the service starts before Tailscale is signed in, so control-service.py now re-reads the allowlist on demand (every 60 s, every 5 s while empty), the 401 says when the PC has no allowed logins, and start-litellm.ps1 warns when the router starts with an empty allowlist. Verified: install and uninstall twice, a fresh logoff and logon (status, up and down from the Mac), the repetition restarting a killed service, and the ACL unchanged. Limits: the PC must be on with the user logged in; the router reads its allowlist only at start.
<!-- SECTION:FINAL_SUMMARY:END -->
