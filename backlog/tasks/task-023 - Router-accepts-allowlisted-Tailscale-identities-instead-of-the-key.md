---
id: TASK-023
title: Router accepts allowlisted Tailscale identities instead of the key
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 14:31'
updated_date: '2026-10-19 15:21'
labels: []
milestone: m-3
dependencies:
  - TASK-022
references:
  - config/custom_auth.py
  - config/litellm.yaml
  - scripts/ai-up.ps1
  - scripts/ai-down.ps1
priority: high
ordinal: 23000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
m-3 replaces the shared router key for remote devices with the Tailscale identity (user decision 2026-10-19: the Tailscale login is the credential for remote devices). The router authenticates in config/custom_auth.py (TASK-011: constant-time key comparison, 401 otherwise). Programs on the PC can reach the loopback port and could set identity headers themselves; the user accepted that, since a program running as the user can already read the key from Credential Manager. Port and HTTP/HTTPS choices come from the spike.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A request forwarded by tailscale serve from an allowlisted login is accepted without a router key, on a local and a Claude model
- [x] #2 A request from a login not on the allowlist, or with neither identity nor key, gets 401; the key still works for calls made on the PC (claude-local.ps1)
- [x] #3 The allowlist is configuration, not code, and holds no secret
- [x] #4 ai-up publishes the router in the mode chosen in the spike and ai-down removes it; a second ai-up and ai-down after a killed router still behave as in TASK-016
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Research (done): serve --http 4000 --set-path / off removes only the / route and keeps others (/control later); TCP and HTTP cannot share port 4000 either way, so a TCP config left by the old ai-up must be removed first; serve status --json shows TCP."4000".TCPForward (TCP mode) or TCP."4000".HTTP plus Web.<host>:4000.Handlers; the PC own login is status --json User[Self.UserID].LoginName.
2. config/custom_auth.py: accept a request whose Tailscale-User-Login (case-insensitive) is in LOCAL_AI_ALLOWED_LOGINS; otherwise the key as before; otherwise 401.
3. scripts/lib/stack.ps1 + start-litellm.ps1: the allowlist is D:\local-ai\allowed-logins.txt when it exists (one login per line, # comments), otherwise the login the PC itself is signed in with; injected into the router process environment only, never in the repo.
4. ai-up publishes / in HTTP mode (removing a leftover TCP config first) and prints the MagicDNS URL; ai-down removes only the / route (and a leftover TCP config).
5. Tests: custom_auth unit test with fake requests (allowlisted, other login, no identity, key, wrong key); live: through the MagicDNS name without key /v1/models 200 and Claude Code on local-coder and sonnet with a key-free launcher; loopback without key 401, claude-local.ps1 with key works; allowlist file with another login: through the name without key 401, with key 200; second ai-up, ai-down after a killed router, ai-down leaves a /control route alone.
6. Tell the user: the Mac URL must become the MagicDNS name (the IP gets 404 in HTTP mode) until TASK-024 changes setup.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Harness D:\local-ai\scratch\id\ (test_custom_auth.py, live.ps1, marker.ps1, codes.ps1). Found while testing: without x-litellm-api-key in the request, LiteLLM treats Authorization as the proxy credential and does not forward the Claude OAuth token, so sonnet failed with Missing Anthropic API Key while local models worked; fixed by having identity clients send the non-secret marker x-litellm-api-key: tailscale-identity (documented in custom_auth.py). Criterion 1 was tested from the PC through its own tailnet name (same user identity as the Mac); the Mac key-free run is TASK-024. The allowlist file was only used for the negative test and removed afterwards. Machine left with no serve config and the stack down.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
The router now lets in requests that tailscale serve forwards from an allowlisted Tailscale login, with no router key; the key keeps working for calls made on the PC. The allowlist is D:\local-ai\allowed-logins.txt when present, otherwise the PC own Tailscale login, injected into the router process only, so no email address is in the repo. ai-up publishes the router route in HTTP mode (migrating the old TCP forward) and prints the MagicDNS URL; ai-down removes only that route, leaving room for the control service route. One LiteLLM quirk needed a workaround: it forwards the Claude subscription token only if x-litellm-api-key is present, so identity clients send the fixed non-secret marker tailscale-identity. Verified with an 11-case unit test and live: identity through the tailnet name on Claude and both local models, 401 for other logins and for loopback without key, TASK-016-style ai-up/ai-down behaviour. Consequence: the Mac must use the MagicDNS URL from now on (the IP gets 404 in HTTP mode). Recorded in doc-002.
<!-- SECTION:FINAL_SUMMARY:END -->
