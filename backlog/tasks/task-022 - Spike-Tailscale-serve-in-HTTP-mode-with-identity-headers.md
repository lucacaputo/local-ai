---
id: TASK-022
title: 'Spike: Tailscale serve in HTTP mode with identity headers'
status: To Do
assignee: []
created_date: '2026-10-19 14:31'
labels: []
milestone: m-3
dependencies: []
references:
  - config/custom_auth.py
  - scripts/ai-up.ps1
documentation:
  - backlog/docs/doc-002 - PRD-changes-and-implementation-log.md
priority: high
ordinal: 22000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The router is published with tailscale serve --tcp 4000 (decision-006), so it only sees 127.0.0.1 and cannot tell who calls. Remote clients prove themselves with the shared router key, which can only be moved to a device from the PC (copy-router-key.ps1): a problem when the user is away. In HTTP mode tailscale serve is expected to add identity headers (Tailscale-User-Login, Tailscale-User-Name) to requests it forwards from user devices, which m-3 wants to use instead of the key. Before building on that, the behaviour has to be confirmed on this tailnet: whether headers sent by the client are stripped, what local callers look like, whether Claude Code streaming passes through, and how the router and the planned control service share the tailnet. Tailscale 1.104.1 on the PC; the Mac is a user device, not tagged. The remote checks need the user at the Mac.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A test listener behind tailscale serve in HTTP mode receives Tailscale-User-Login with the user login for requests from the Mac, and no identity header for requests made on the PC to the loopback port
- [ ] #2 Identity headers sent by the Mac client itself are stripped or overwritten by tailscale serve, shown with a forged header
- [ ] #3 A streaming Claude Code session from the Mac works through HTTP-mode forwarding to the real router, on a local and a Claude model
- [ ] #4 HTTP vs HTTPS and the port layout for the router and the control service are decided with reasons, and the findings and a go/no-go are recorded in doc-002
<!-- AC:END -->
