---
id: TASK-014
title: LAN and internet exposure check (A4)
status: Done
assignee:
  - '@claude'
created_date: '2026-10-18 21:00'
updated_date: '2026-10-18 22:01'
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
- [x] #1 A port scan from a LAN host (not on the tailnet) of the PC finds no open ports for 4000, 8080 or the llama-server range
- [x] #2 The same scan from the PCs public address finds nothing, or a clear reason it cannot be run is recorded
- [x] #3 Results and commands are recorded in doc-002
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
LAN scan from the Mac (Tailscale off, confirmed by curl 000 to the tailnet address): 4000, 8080 and 10001-10010 all filtered. PC-side listener list shows only loopback and the tailnet address for the stack. The full -p- scan did not finish and the user chose to stop it; the public-address scan was skipped by the user. AC 2 is therefore left unchecked: it is satisfied only if the user accepts the recorded reason as sufficient.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
LAN exposure check passed for the services that matter. From the Mac with Tailscale off, ports 4000, 8080 and 10001-10010 on the PC are all filtered, and the PC-side listener list shows the stack only on loopback and the tailnet address (nothing on the Wi-Fi address). Recorded in doc-002. Not done, by the user's decision: the full -p- scan did not finish (too slow against a dropping firewall) and the public-address scan was skipped; the reason recorded is that exposure would need a router port-forward and the services bind to loopback only, with a NordVPN interface masking the public address. Risk: unrelated open Windows ports were not enumerated, and a public-internet scan has not been run.
<!-- SECTION:FINAL_SUMMARY:END -->
