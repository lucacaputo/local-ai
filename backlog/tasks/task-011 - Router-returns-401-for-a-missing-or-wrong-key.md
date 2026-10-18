---
id: TASK-011
title: Router returns 401 for a missing or wrong key
status: Done
assignee:
  - '@claude'
created_date: '2026-10-18 21:00'
updated_date: '2026-10-18 21:06'
labels: []
milestone: m-1
dependencies: []
priority: medium
ordinal: 11000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Found in the MVP acceptance run (doc-002 carry-over): a request without the router key returns HTTP 500 instead of 401. Remote clients with a misconfigured key will see an opaque server error, and scanners get a misleading signal about the router.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A request with no x-litellm-api-key header gets HTTP 401
- [x] #2 A request with a wrong key gets HTTP 401
- [x] #3 A request with the right key still works for local-coder and a Claude model
- [x] #4 The change and its cause are recorded in doc-002
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Reproduce the 500 and the wrong-key response on a standalone router and read the log.
2. Pick the smallest fix that covers both cases without a database or a new pinned dependency.
3. Verify with none/wrong/right keys, then through claude-local on local-coder and sonnet.
4. Record the finding and fix in doc-002.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Root cause: with no database, LiteLLM's auth error handler imports the prisma package, which is absent, so a missing key crashed into HTTP 500. A wrong key took a different path ("No connected db") and gave 400. Installing prisma fixed only the no-key case, so I did not keep it (venv is back at the pinned state). Fix: config/custom_auth.py via general_settings.custom_auth, constant-time compare with the master key, ProxyException 401. Verified on a standalone router: none/wrong/wrong-suffix 401, right key 200 in x-litellm-api-key (with and without Bearer) and Authorization, /health/liveliness 200 without a key. Full stack: ai-up healthy in 13.3 s, local-coder and sonnet both answered "pong" through claude-local, then ai-down (VRAM 23540 -> 2149 MiB). Test helpers are in D:\local-ai\scratch (probe.ps1, probe2.ps1, t11.ps1), outside the repo.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Router answers 401 for a missing or wrong key instead of 500/400. config/custom_auth.py (wired in config/litellm.yaml) compares the x-litellm-api-key or Authorization bearer with the master key in constant time; no new dependency, no database. Verified with none, wrong, wrong-suffix and right keys, and through claude-local on local-coder and sonnet on the full stack. Recorded in doc-002. Risk: custom_auth replaces LiteLLM's own key handling, which is acceptable here because the only valid credential is the master key; revisit if virtual keys are ever introduced.
<!-- SECTION:FINAL_SUMMARY:END -->
