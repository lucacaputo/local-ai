---
id: decision-006
title: >-
  Publish the router on the tailnet with tailscale serve, bind everything to
  loopback
date: '2026-10-18 16:16'
status: >-
  accepted; second-device check done in TASK-013 and LAN check in TASK-014 (see
  doc-002); the TCP forward was replaced by tailscale serve in HTTP mode with
  identity headers and a /control route on the same port (decision-008)
---
## Context

PRD N2/R5: nothing reachable from the LAN or internet, router reachable over Tailscale. The PRD worded this as "LiteLLM binds to the Tailscale interface address and loopback", but LiteLLM (uvicorn) takes a single bind address, so that needs a second listener or a wildcard bind. Tailscale 1.104.1 is installed (PC `caps`, 100.111.199.22, tailnet `tail0144cb.ts.net`).

## Decision

LiteLLM, llama-swap and llama-server bind to `127.0.0.1` only. The router port is published to the tailnet with `tailscale serve --bg --tcp 4000 tcp://127.0.0.1:4000`, which makes `tailscaled` listen on the Tailscale addresses (100.111.199.22 and the IPv6 tailnet address) and forward to the loopback router. `scripts/start-litellm.ps1` refuses any non-loopback `-ListenHost`; llama-swap is always started with `-listen 127.0.0.1:8080`. No extra Windows Firewall rule: the installer's `Tailscale-In` rules already allow inbound only to the Tailscale addresses, and nothing else listens on a non-loopback address. `ai-up` turns the serve on and `ai-down` turns it off (`tailscale serve --tcp=4000 off`).

## Consequences

- Verified with netstat: 127.0.0.1:4000 (LiteLLM), 127.0.0.1:8080 (llama-swap), 127.0.0.1:10001 (llama-server) and tailscaled on 100.111.199.22:4000 / the IPv6 tailnet address; the Wi-Fi (192.168.1.101) and WSL (172.21.160.1) addresses refuse 4000, 8080 and 10001.
- Remote devices use `http://100.111.199.22:4000` or `http://caps.tail0144cb.ts.net:4000` plus the router key; only 4000 is published, never 8080 or 10001.
- The Tailscale service starts with Windows (it is idle and exposes nothing without a serve config); the AI stack itself never auto-starts.
- Access control beyond "device is on the tailnet" is the router key and Tailscale ACLs; tighten the ACL to the user's own devices when more devices join.
- Not yet tested from a second tailnet device (only the PC is on the tailnet); the remote milestone repeats the check from a laptop or phone.
