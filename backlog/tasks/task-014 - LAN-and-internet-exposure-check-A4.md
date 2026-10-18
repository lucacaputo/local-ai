---
id: TASK-014
title: LAN and internet exposure check (A4)
status: To Do
assignee: []
created_date: '2026-10-18 21:00'
labels: []
milestone: m-1
dependencies: []
priority: high
ordinal: 14000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
N2 and acceptance criterion A4: nothing may be reachable from the LAN or the public internet. TASK-007 bound the services to loopback and the tailnet and scoped the firewall, but it was never verified from a different machine on the LAN.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A port scan from a LAN host (not on the tailnet) of the PC finds no open ports for 4000, 8080 or the llama-server range
- [ ] #2 The same scan from the PCs public address finds nothing, or a clear reason it cannot be run is recorded
- [ ] #3 Results and commands are recorded in doc-002
<!-- AC:END -->
