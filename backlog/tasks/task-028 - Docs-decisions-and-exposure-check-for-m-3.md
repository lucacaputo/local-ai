---
id: TASK-028
title: 'Docs, decisions and exposure check for m-3'
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 14:31'
updated_date: '2026-10-19 22:19'
labels: []
milestone: m-3
dependencies:
  - TASK-023
  - TASK-024
  - TASK-025
  - TASK-026
  - TASK-027
references:
  - README.md
  - docs/remote-client-macos.md
documentation:
  - backlog/docs/doc-002 - PRD-changes-and-implementation-log.md
priority: medium
ordinal: 28000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
m-3 changes two recorded decisions: decision-005 (one shared key for the router and every client) and decision-006 (router published with tailscale serve in TCP mode, everything bound to loopback). The README security notes, the Mac guide and doc-002 describe the old model, and the tailnet gains a second port. The backlog CLI (1.54.0) can only set a decision title and status, not its body.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A new decision records identity-based auth and the control service, and the statuses of decision-005 and decision-006 point to it
- [x] #2 The README (usage, security notes, troubleshooting) and doc-002 describe the final m-3 setup
- [x] #3 Listener check with the stack up and down: only the router and control ports are reachable on the tailnet, and nothing new listens on the LAN address (as in TASK-014)
- [x] #4 Secret scan of the worktree and git history is clean
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. decision-008 with the CLI (title and status only; the CLI cannot write a body): identity-based auth for remote devices and the control service. Its context, decision and consequences go into a doc-002 section that the status points to. decision-005 status: still holds on the PC, superseded for remote devices by decision-008. decision-006 status: TCP forward replaced by HTTP mode with identity headers and a /control route (decision-008).
2. doc-002: update the deviation rows (key now PC-only, tailnet port in HTTP mode with / and /control) and add rows for client auth by identity (PRD section 4/5 'clients use a local key') and the control service started at logon (F4: no auto-start; the stack itself still never starts by itself). Add the missing TASK-024, TASK-025 and TASK-027 sections, the decision-008 section, and a TASK-028 section with the exposure check and the secret scan.
3. README: diagram, install (install-control.ps1), daily use (ai-remote.sh), where things live (control service, allowlist, control.log; key PC-only), troubleshooting (401 by identity, 404 by IP, remote start), security notes (who gets in, loopback identity accepted, browser refusal, routes on port 4000, control service, what was tested). Ask the user whether the unused scripts/copy-router-key.ps1 goes.
4. Exposure check, stack down and up with a model loaded: PC listeners of the stack (router, control service, llama-swap, llama-server on 127.0.0.1 only; tailscaled on the tailnet addresses), tailscale serve status (port 4000 only, routes / and /control), nothing from the stack on the LAN, WSL or VPN addresses; from the Mac: nmap of the tailnet name (only 4000 open) and of the LAN address with Tailscale off (all filtered), as in TASK-014.
5. Secret scan as in TASK-019: tracked files and git log --all -p for the current router key (exact match inside PowerShell, count only), token patterns (sk-local-, sk-ant-, ghp_, github_pat_, hf_, AKIA, tskey-, private-key blocks), the user's email in tracked files, tracked .env/.key/.pem/.p12/.pfx; also the logs folder for the router key.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Decisions: decision-008 created with the CLI (title and status; the body is the empty template, its content goes into doc-002); decision-005 and decision-006 statuses point to it.

Exposure check from the PC (D:\local-ai\scratch\m3\exposure.ps1). Addresses: Wi-Fi 192.168.1.101, WSL vEthernet 172.21.160.1, NordLynx 10.5.0.2, Tailscale 100.111.199.22. Stack down: control service 127.0.0.1:4100; tailscaled on 100.111.199.22:4000 and the IPv6 tailnet address (plus its own peer API ports 41431 and 61944 on the tailnet addresses); serve: port 4000 only, HTTP, /control -> 127.0.0.1:4100; Funnel off. Stack up (ai-up -Warm, then local-coder-q6 loaded): router 127.0.0.1:4000, control 127.0.0.1:4100, llama-swap 127.0.0.1:8080, llama-server 127.0.0.1:10001 and 127.0.0.1:10002; serve: / -> 127.0.0.1:4000 and /control -> 127.0.0.1:4100. Non-loopback listeners other than tailscaled on the tailnet addresses: none, in both states. Probes from WSL: tailnet address 4000 open, 4100/8080/10001/10002 closed; Wi-Fi and NordLynx addresses: all five closed.

Secret scan (73 tracked files, 35 commits, git log --all -p 544 KB): pattern hits only name prefixes in docs and init-secrets.ps1; no token values (sk-local- plus hex, sk-ant- plus token, long Bearer values): 0; no tracked .env/.key/.pem/.p12/.pfx; allowed-logins.txt not tracked; the user's email in no tracked file and no patch. Current router key (exact match inside PowerShell, D:\local-ai\scratch\m3\key-scan.ps1): 0 of 73 tracked files, not in the history, 0 of 76 worktree files including ignored ones, 0 of 50 log files.

Docs: doc-002 deviation rows updated (bindings and routes, key PC-only) plus two new rows (client auth by Tailscale login; control service vs F4); new sections TASK-024, TASK-025, TASK-027, decision-008 (context, decision, consequences) and the TASK-028 exposure check and secret scan. README: diagram, install-control.ps1, daily use from the Mac, where things live (allowlist, control service, Mac config, key PC-only), troubleshooting (401 by identity, 404 by IP, ai-remote errors), security notes (bindings and routes, who gets in, the router key, refusals, control service, tested and not tested). Stale header comments fixed in start-litellm.ps1 (TCP forward), start-control.ps1 (logon start is done) and copy-router-key.ps1 (no Keychain prompt any more; kept as a key fallback for clients that cannot use their login). Pending: nmap from the Mac (tailnet name with the stack up and down, LAN address with Tailscale off).

nmap from the Mac (user): tailnet name with the stack up and local-coder loaded (chat request with the marker, no key: 200): 4000 open, 4100, 8080, 10001-10010 filtered; Wi-Fi address 192.168.1.101 with Tailscale off on the Mac: all 13 filtered; after ai-remote.sh down (VRAM 22,697 -> 1,348 MiB): tailnet name 4000 open (the /control route), all others filtered. copy-router-key.ps1 kept as a fallback (user decision).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
m-3 documented and checked. decision-008 records identity-based auth for remote devices and the control service; the CLI can write only its title and status, so its context, decision and consequences are in doc-002 and the status points there. decision-005 (key now PC-only) and decision-006 (HTTP mode with / and /control) point to it. doc-002: updated and new deviation rows, the missing TASK-024, TASK-025 and TASK-027 sections, the decision-008 text, and the exposure and secret-scan results. README: diagram, install-control.ps1, remote use from the Mac, where things live, troubleshooting, security notes. Stale comments fixed in three scripts; copy-router-key.ps1 kept as a key fallback (user decision). Exposure: with the stack down and up, every stack process listens on 127.0.0.1 only; tailscale serve publishes port 4000 only (Funnel off); from the Mac only 4000 is open on the tailnet, and the Wi-Fi address shows everything filtered. Secret scan clean: no token values or secret files, and the router key is in no tracked file, commit, worktree file or log.
<!-- SECTION:FINAL_SUMMARY:END -->
