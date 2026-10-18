---
id: TASK-006
title: Secret storage and injection for the router
status: Done
assignee:
  - '@claude'
created_date: '2026-10-18 14:13'
updated_date: '2026-10-18 16:09'
labels: []
milestone: m-0
dependencies:
  - TASK-001
  - TASK-003
documentation:
  - backlog/docs/doc-0001-PRD.md
priority: high
type: task
ordinal: 6000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The router master key and the client local key must never sit in plaintext in the repo or on disk (PRD F6, R7). They are injected into process environments at start from the secret store chosen in the inventory task.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The router key (used as both LiteLLM master key and client local key, decision-005) lives only in the chosen secret store
- [x] #2 A helper starts LiteLLM with secrets injected into its environment
- [x] #3 Claude Code on the PC gets the local key from the secret store, not from a plaintext file
- [x] #4 A search of the repo and config files finds no secret values
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. scripts/lib/secrets.ps1: Windows Credential Manager helpers for PowerShell 5.1 via P/Invoke on advapi32 (CredReadW, CredWriteW, CredDeleteW, CredFree): Set-/Get-/Remove-LocalAiSecret. Target "local-ai/router-key", persistence local-machine (survives reboot, DPAPI-protected, tied to the Windows user).
2. scripts/init-secrets.ps1: creates a random 48-hex-char key and stores it if none exists (never printed, never written to a file); -Rotate replaces it.
3. scripts/start-litellm.ps1: reads the key from the store, sets LITELLM_MASTER_KEY (and PYTHONUTF8=1) only in the child process environment, starts LiteLLM from config/litellm.yaml; parameters for the listen host/port (TASK-007 sets the tailnet binding) and logs to the git-ignored logs folder. TASK-009 will call it.
4. scripts/claude-local.ps1: launches Claude Code with ANTHROPIC_BASE_URL and ANTHROPIC_CUSTOM_HEADERS (x-litellm-api-key) built from the store in the child process only, plus --settings config/claude-settings.json; ANTHROPIC_API_KEY/AUTH_TOKEN stay unset.
5. Verify: round trip and cmdkey /list shows the entry but not the value; router started by the helper accepts the stored key and rejects another; claude-local -p works with local-coder; scan the repo, config and D:\local-ai\logs for the key value (scanner reads it in memory, never prints it).
6. Record in decision form that one key serves as master and client key. Stop for review.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Results (2026-10-18):

Built (scripts/, no secrets in them): lib/secrets.ps1 (Credential Manager via P/Invoke on advapi32; target local-ai/router-key, generic credential, persisted local-machine), init-secrets.ps1 (random 24-byte key as sk-local-<48 hex>, stored without printing; idempotent, -Rotate), start-litellm.ps1 (key from the store into the router process environment only; parameters -ListenHost/-Port/-Root; refuses if the port is busy; sets PYTHONUTF8=1; health-waits), claude-local.ps1 (builds ANTHROPIC_BASE_URL and the x-litellm-api-key header from the store in the Claude Code process, restores the caller's environment afterwards, passes all arguments to claude with --settings config/claude-settings.json). Decision-005 records the one-key design.

Verified: credential created (length 57) and idempotent re-run; cmdkey /list shows target, type, user and local-machine persistence but not the value; router started by start-litellm.ps1: stored key -> 200, wrong key -> 400, no key -> 500 (known no-DB quirk, still denied); the key is not in the router's command line; claude-local.ps1 -p --model local-coder returned PONG through router + llama-swap, and the header did not leak into the calling shell; a scan of 177 files (whole repo including .git, D:\local-ai root and logs) found the key in 0 files. Bugs found while testing and fixed: PowerShell read claude's -p as an abbreviation of -PipelineVariable (launcher now uses $args only), and $ErrorActionPreference=Stop turned claude's stderr warning into a terminating error (removed). Test scripts are in D:\local-ai (test-secrets*.ps1), outside the repo.

Limits: the key is readable by any process running as your Windows user (Credential Manager protects against other users, not against your own processes); it is visible in the environment of the router and Claude Code processes. Remote devices will need the key in their own store.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
The router key now lives only in Windows Credential Manager (target local-ai/router-key) and in the environments of the processes that need it. scripts/lib/secrets.ps1 wraps the Win32 credential API for PowerShell 5.1; init-secrets.ps1 creates (or rotates) a random key without printing it; start-litellm.ps1 starts the router with the key injected; claude-local.ps1 launches Claude Code against the router with the key built into its process environment only (caller environment restored). One key serves as master and client key (decision-005) because separate client keys need a database. Verified: stored key accepted, wrong or missing key rejected, claude-local -p works on local-coder, and a scan of 177 files (repo incl. .git, D:\local-ai, logs) found the key nowhere; cmdkey does not reveal the value.

Risks/follow-ups (not created as tasks): the key is readable by any process of the same Windows user and visible in the router and Claude Code process environments; remote devices need the key in their own store (later milestone); a missing key returns HTTP 500 instead of 401 (LiteLLM no-DB quirk); start-litellm.ps1 does not yet track its PID or manage llama-swap (TASK-009).
<!-- SECTION:FINAL_SUMMARY:END -->
