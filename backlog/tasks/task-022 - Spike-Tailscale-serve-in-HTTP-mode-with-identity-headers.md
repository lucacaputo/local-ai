---
id: TASK-022
title: 'Spike: Tailscale serve in HTTP mode with identity headers'
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 14:31'
updated_date: '2026-10-19 14:46'
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
- [x] #1 A test listener behind tailscale serve in HTTP mode receives Tailscale-User-Login with the user login for requests from the Mac, and no identity header for requests made on the PC to the loopback port
- [x] #2 Identity headers sent by the Mac client itself are stripped or overwritten by tailscale serve, shown with a forged header
- [x] #3 A streaming Claude Code session from the Mac works through HTTP-mode forwarding to the real router, on a local and a Claude model
- [x] #4 HTTP vs HTTPS and the port layout for the router and the control service are decided with reasons, and the findings and a go/no-go are recorded in doc-002
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Research (done): Tailscale 1.104.1 serve has --http, --https, --set-path and --accept-app-caps; tailscaled knows Tailscale-User-Login, -User-Name, -User-Profile-Pic and -App-Capabilities; CertDomains is empty (HTTPS certificates not enabled on the tailnet); the PC node is not tagged; unix-socket targets are not available on Windows. The ACL grant only opens tcp:4000, so the tests use tailnet port 4000.
2. Echo listener (D:\local-ai\scratch\ts\echo.py, LiteLLM venv Python, no new packages) on 127.0.0.1:4090 that returns the headers it received; stack down; tailscale serve --bg --http 4000 http://127.0.0.1:4090.
3. PC tests: loopback (expect no identity), the PC own tailnet address (expect the PC node identity), forged Tailscale-User-Login from the PC through the tailnet.
4. Mac tests (user): plain request and a forged Tailscale-User-Login; record what arrives.
5. Real router behind HTTP-mode serve on 4000 (ai-up -NoTailnet, then serve --http 4000 to 127.0.0.1:4000); user runs a streaming claude-local.sh session on the Mac with a local and a Claude model (the Mac still has the key).
6. Restore: serve reset, ai-down; ai-up publishes TCP as before. Decide HTTP vs HTTPS and the port layout for router and control service; record findings and go/no-go in doc-002.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Harness D:\local-ai\scratch\ts\ (echo.py, pc-tests*.ps1, stream-timing.ps1). PC: loopback request has no identity headers; through the tailnet name the listener sees Tailscale-User-Login (user login), -User-Name, -User-Profile-Pic, Tailscale-Headers-Info, X-Forwarded-For (device tailnet IP), X-Forwarded-Host, from client 127.0.0.1; forged Tailscale-User-Login overwritten, forged Tailscale-App-Capabilities dropped. HTTP mode routes by host: the tailnet IP gets 404. Mac (user): own login with the Mac tailnet IP in X-Forwarded-For, forged login overwritten, IP 404, interactive claude-local.sh with LOCAL_AI_ROUTER set to the MagicDNS name streams on local-coder; sonnet seemed to print at once, measured on the PC as the same delta pattern over loopback and through serve (85 vs 86 deltas, about 3 s), so not caused by serve. Path routes: / to the router and /echo to the listener together on port 4000, prefix stripped; a route to a dead port answers 502. Restored afterwards: serve reset, stack down, echo stopped. Decisions in doc-002: HTTP not HTTPS, MagicDNS name for clients, one port with / and /control, allowlist outside the repo. Consequence for TASK-026: the existing tcp:4000 ACL grant already covers /control, so its ACL criterion becomes a check that no ACL change is needed.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Spike passed: tailscale serve in HTTP mode gives the router a trustworthy caller identity. Requests forwarded from the Mac (and from the PC through its own tailnet name) carry Tailscale-User-Login with the user login and X-Forwarded-For with the device tailnet IP; identity headers sent by the client are overwritten or dropped; loopback requests carry none. Claude Code streams through HTTP-mode forwarding on local and Claude models. Decided: HTTP (WireGuard already encrypts, HTTPS is not enabled and would publish the host name in CT logs); clients must use the MagicDNS name because HTTP mode routes by host (IP gives 404); one tailnet port 4000 with path routes, / for the router and /control for the control service, so the ACL stays as it is; the allowlist (an email address) lives outside the repo. Recorded in doc-002 with a go. Test setup removed; normal TCP publishing returns with the next ai-up.
<!-- SECTION:FINAL_SUMMARY:END -->
