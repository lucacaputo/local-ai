---
id: TASK-031
title: Router refuses browser requests on the identity path
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 15:49'
updated_date: '2026-10-19 15:55'
labels: []
milestone: m-3
dependencies: []
references:
  - config/custom_auth.py
documentation:
  - backlog/docs/doc-002 - PRD-changes-and-implementation-log.md
priority: high
ordinal: 31000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Since TASK-023 the router lets in any request that tailscale serve forwards from an allowlisted Tailscale login, without a key. tailscale serve attaches that identity to every request from the device, including requests made by a web page open in the user browser on the Mac or the PC. LiteLLM answers cross-origin requests permissively (preflight 200, Access-Control-Allow-Origin: *), so a malicious page that guesses the address (http://caps:4000) could use the local models and read the answers, and the identity has admin rights on the router. Found on 2026-10-19 while designing the control service; checked through the tailnet name with Origin: https://evil.example: preflight 200, GET /v1/models 200, POST chat on local-coder 200, all with ACAO *. Browsers always send Origin on cross-origin requests and POSTs, and Sec-Fetch-Site on modern versions; Claude Code sends neither. The control service (TASK-025) needs the same rule.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A request through the tailnet name from an allowlisted login that carries an Origin or a Sec-Fetch-Site header gets 401 unless it has the router key, for GET /v1/models and for a POST to a local model
- [x] #2 Claude Code through the tailnet name still works without a key, from the PC and from the Mac (claude-local.sh), on a local and a Claude model
- [x] #3 Key-authenticated requests are unaffected, also with an Origin header (claude-local.ps1 works)
- [x] #4 The custom_auth unit test covers the new cases, and doc-002 records the gap and the fix
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. config/custom_auth.py: the identity path also requires that the request carries neither Origin nor Sec-Fetch-Site (browser-only headers); otherwise it falls through to the key check.
2. Extend the unit test (D:\local-ai\scratch\id\test_custom_auth.py) with Origin and Sec-Fetch-Site cases, with and without the key.
3. Restart the router; rerun the cross-origin probe (expect 401 for GET and POST; the CORS preflight may still answer 200, the real request is refused); Claude Code through the tailnet name with the marker on local-coder and sonnet from the PC; claude-local.ps1 with the key; the user runs claude-local.sh on the Mac.
4. Record in doc-002.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Unit test 16/16 (D:\local-ai\scratch\id\test_custom_auth.py). Live through the tailnet name after a router restart (D:\local-ai\scratch\id\cors.ps1): Origin GET /v1/models 401, Origin POST local-coder 401, Sec-Fetch-Site only 401, marker + Origin 401, Origin + key 200, no browser headers 200; preflight still 200 from the LiteLLM CORS middleware, harmless since the request behind it is refused. Claude Code from the PC through the tailnet name with the marker answered on sonnet and local-coder; claude-local.ps1 with the key answered. Mac check pending (no pull needed, the Mac scripts did not change).

Mac (user): claude-local.sh works on a local and a Claude model after the fix.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Closed a gap opened by TASK-023: tailscale serve attaches the user identity to requests made by web pages in the browser too, and LiteLLM answers cross-origin requests with Access-Control-Allow-Origin: *, so a malicious page that guessed the address could have used the local models with admin rights on the router. custom_auth.py now lets a request in by identity only if it carries neither Origin nor Sec-Fetch-Site (browser-only headers); otherwise the key is required. Verified: browser-style requests through the tailnet name get 401 (GET and POST), the key still works with Origin, and Claude Code works from the PC and the Mac on local and Claude models. Unit test 16/16; recorded in doc-002. The control service applies the same rule.
<!-- SECTION:FINAL_SUMMARY:END -->
