---
id: TASK-016
title: Test ai-up and ai-down failure modes
status: Done
assignee:
  - '@claude'
created_date: '2026-10-18 22:01'
updated_date: '2026-10-19 12:01'
labels: []
milestone: m-2
dependencies: []
priority: medium
ordinal: 16000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
ai-up and ai-down were only exercised on clean starts and stops. A crashed router, a stale run\stack.json with dead pids, a port already taken or a second ai-up should leave the machine in a state the next ai-up or ai-down can fix, with no orphaned llama-server holding 23 GB of VRAM.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 ai-down after a killed router, a killed llama-swap, and a stale state file each ends with no stack process left and VRAM near idle
- [x] #2 A second ai-up while the stack runs, and ai-up after a crash, either work or fail with a clear message and leave nothing half-started
- [x] #3 Any script fix is made, and the cases and outcomes are recorded in doc-002
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Test harness outside the repo (D:\local-ai\scratch\fm\): snap.ps1 prints stack processes, listeners on 4000/8080/10001, tailnet serve status, stack.json presence and VRAM; each case runs through powershell.exe from WSL. Start from the idle baseline (no processes, 1568 MiB, no serve, no state file).
2. ai-down cases (AC1), each with the model loaded (ai-up -Warm): A killed router; B killed llama-swap only (llama-server orphaned, holds the VRAM); C stale stack.json with dead pids and nothing running; C2 corrupt/empty stack.json (suspected: ConvertFrom-Json throws under ErrorActionPreference Stop and ai-down stops before touching anything).
3. ai-up cases (AC2): D second ai-up while running; E1 ai-up after a killed router (llama-swap alive); E2 ai-up after both killed with an orphaned llama-server; E3 tailnet serve left on after a crash; F start fails midway (foreign listener on 0.0.0.0:4000 passes the 127.0.0.1 pre-check, start-litellm refuses) -> expect cleanup and the foreign listener left alone.
4. Fix any script defect found, rerun the failing case, run the happy path (ai-up -> request -> ai-down) once more as regression.
5. Record cases and outcomes in doc-002.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Cases A, B, C1-C5, D, E1-E3, F run on the real stack from WSL via powershell.exe; table with numbers in doc-002 (section 'ai-up and ai-down failure modes (TASK-016)'). Harness and snapshots are outside the repo: D:\local-ai\scratch\fm\ (snap.ps1, orphan.ps1, foreign.ps1, hang1.ps1). Two defects found and fixed: (1) ai-up never returned to a WSL caller because Start-Process -Redirect* children inherit the caller's output pipe; fixed with Start-Detached (cmd.exe /c with redirects) in scripts/lib/stack.ps1, used by ai-up.ps1 and start-litellm.ps1; (2) a corrupt run\stack.json made ai-down abort before stopping anything; now a warning. Scope note: (1) is beyond the three failure modes listed in the description; I treated it as covered by AC #3 ('any script fix') because it is the 'WSL-launch hang' the README task named and it blocked testing from WSL. README WSL paragraph corrected (my earlier text said ai-up was meant to work from WSL; it did not until this fix). Observed, not investigated: litellm.err.log has a LiteLLM warning about general_settings.custom_auth_run_common_checks (from the TASK-011 custom_auth hook).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
ai-up and ai-down were run through ten failure scenarios on the real stack and now leave a recoverable machine in all of them. ai-down ends with no stack process, listener, tailnet serve or state file and VRAM back to idle after a killed router, a killed llama-swap, an orphaned llama-server holding 18.8 GB (18835 -> 1696 MiB in 6.5 s), a stale, empty or partial stack.json, and a corrupt stack.json with the stack running. ai-up either works (second run: 'already running', no duplicates; after a hard crash with the tailnet serve and state left behind) or refuses with a clear message and changes nothing (partly running stack, port 10001 taken), and a start that fails midway (foreign listener on 0.0.0.0:4000) cleans up llama-swap, the state file and the serve and leaves the foreign process alone. Two script fixes: ai-down no longer aborts on an unreadable stack.json (it used to fail before stopping anything, every time); and ai-up no longer hangs a caller that waits for its output pipe, such as powershell.exe from WSL (llama-swap and the router now start through Start-Detached, cmd.exe /c with log redirects; ai-up -Warm from WSL returns in 22 s, exit 0, key still reaches the router, logs still written, stack.json records the real llama-swap pid). Cases, numbers and the measured hang are in doc-002. Not tested: Ctrl-C of ai-up mid-start, ai-down racing ai-up, a real game, ai-up from a Windows terminal after the change (only the powershell.exe-from-WSL path was run). Risks: Start-Detached returns the cmd.exe wrapper process, not the child; ai-down finds processes by listener and install path, so it does not depend on that. A LiteLLM warning about custom_auth_run_common_checks appears in litellm.err.log (not investigated). Not committed.
<!-- SECTION:FINAL_SUMMARY:END -->
