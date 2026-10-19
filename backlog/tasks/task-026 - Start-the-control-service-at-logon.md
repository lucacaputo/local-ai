---
id: TASK-026
title: Start the control service at logon
status: To Do
assignee: []
created_date: '2026-10-19 14:31'
updated_date: '2026-10-19 14:46'
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
- [ ] #1 An install script registers the control service to start at logon and publishes its port on the tailnet; an uninstall script removes both; running either twice is safe
- [ ] #2 After the user logs off and on again, the service answers status from the Mac while the AI stack stays down until up is called
- [ ] #3 The control service is reachable from the Mac through the existing tcp:4000 ACL grant (one port, /control route, TASK-022), so no ACL change is needed; checked and recorded
- [ ] #4 install.ps1 -CheckOnly or the README tells whether the control service is installed
<!-- AC:END -->
