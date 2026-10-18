---
id: TASK-007
title: Restrict router and model servers to loopback and tailnet
status: Done
assignee:
  - '@claude'
created_date: '2026-10-18 14:13'
updated_date: '2026-10-18 16:18'
labels: []
milestone: m-0
dependencies:
  - TASK-005
documentation:
  - backlog/docs/doc-0001-PRD.md
priority: high
type: task
ordinal: 7000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Nothing may be reachable from the LAN or the internet (PRD N2, R5). The router must still be reachable over Tailscale for remote devices in a later milestone, so it binds to the Tailscale interface address and loopback, while llama-swap and llama-server stay loopback-only.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 LiteLLM listens only on 127.0.0.1; the router is published on the tailnet by tailscaled on the Tailscale addresses (`tailscale serve`, decision-006)
- [x] #2 llama-swap and llama-server listen only on 127.0.0.1
- [x] #3 Inbound access on the Tailscale address is limited by the Tailscale-In firewall rules (local address = the Tailscale addresses), and no other address accepts connections on the stack ports
- [x] #4 `netstat` output confirming the listeners is recorded
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Install Tailscale 1.104.1 with winget (needs a UAC prompt) and have the user sign in to their tailnet; record the 100.x address.
2. Choose how the router becomes reachable on the tailnet: (A) PRD wording: bind LiteLLM to the Tailscale address and loopback (uvicorn takes one --host, so this needs a second listener or 0.0.0.0, which is wider than wanted), or (C) keep LiteLLM on 127.0.0.1 only and publish port 4000 to the tailnet with `tailscale serve --tcp 4000 tcp://127.0.0.1:4000`. (C) leaves nothing listening on the LAN by construction; the tailnet listener is tailscaled itself (WireGuard, ACL controlled). Needs user decision.
3. Windows Firewall: inbound rule for the router port scoped to the Tailscale interface (needs an elevated terminal, run by the user) if (A); under (C) add a defense-in-depth rule or document why none is needed.
4. Prove it: netstat listeners for 8080/10001/4000; connection attempts to the PC LAN (Wi-Fi) and WSL addresses on 4000/8080/10001 must be refused; from the tailnet side (second device, if available) 4000 reachable and 8080 not.
5. Make start-litellm.ps1/ai-up refuse a non-loopback -ListenHost unless it is the Tailscale address; always start llama-swap with -listen 127.0.0.1:8080.
6. Record results; stop for review.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Results (2026-10-18): Tailscale 1.104.1 installed with winget (service starts with Windows), user signed in; PC caps = 100.111.199.22, tailnet tail0144cb.ts.net, no other devices yet. Design: decision-006 (loopback-only binds + tailscale serve).

netstat -ano with the stack running: 127.0.0.1:4000 (LiteLLM python), 127.0.0.1:8080 (llama-swap), 127.0.0.1:10001 (llama-server), 100.111.199.22:4000 and the IPv6 tailnet address :4000 (tailscaled, only while serve is on). Connection attempts from the PC: 127.0.0.1 4000/8080/10001 open; 192.168.1.101 (Wi-Fi) and 172.21.160.1 (WSL) refused on all three; 100.111.199.22 only 4000 open. Through the tailnet address and the MagicDNS name: with key 200, wrong key 400, chat completion on local-light works. Firewall: the installer's Tailscale-In rules allow inbound only for local address 100.111.199.22 and fd7a:115c:a1e0::a401:c7e2 (profiles Domain/Private); no additional rule needed or added, so no elevated step. start-litellm.ps1 now refuses non-loopback -ListenHost and checks port clashes per address (tailscaled and LiteLLM share port 4000 on different addresses). serve was turned off after testing (tailscale serve --tcp=4000 off; status: No serve config); ai-up/ai-down (TASK-009) must switch it on and off.

Not verified: reachability from a second tailnet device (none yet) - repeat in the remote milestone; the Tailscale ACL is the default allow-all for the user's own devices.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Everything in the stack now binds to 127.0.0.1 (LiteLLM :4000, llama-swap :8080, llama-server :10001) and the router is published to the tailnet with `tailscale serve --bg --tcp 4000 tcp://127.0.0.1:4000` (decision-006), instead of binding LiteLLM to the Tailscale address (uvicorn takes one bind address). Tailscale 1.104.1 was installed with winget and signed in (PC caps, 100.111.199.22). Verified with netstat and connection attempts: the Wi-Fi and WSL addresses refuse 4000/8080/10001; on the tailnet address only 4000 answers, with the key accepted (200), a wrong key rejected (400) and a chat request served. The installer's Tailscale-In rules already scope inbound to the Tailscale addresses, so no firewall rule was added. start-litellm.ps1 refuses non-loopback binds and checks port clashes per address; serve was turned off after testing.

Risks/follow-ups (not created as tasks): ai-up/ai-down (TASK-009) must run `tailscale serve --bg --tcp 4000 ...` and `tailscale serve --tcp=4000 off` and start llama-swap with -listen 127.0.0.1:8080; no second tailnet device was available, so the remote check is for the remote milestone; the Tailscale ACL is still the default (tighten when more devices join); the Tailscale service itself starts with Windows.
<!-- SECTION:FINAL_SUMMARY:END -->
