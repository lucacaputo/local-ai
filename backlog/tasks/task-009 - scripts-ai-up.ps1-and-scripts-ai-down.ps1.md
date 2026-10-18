---
id: TASK-009
title: scripts/ai-up.ps1 and scripts/ai-down.ps1
status: Done
assignee:
  - '@claude'
created_date: '2026-10-18 14:13'
updated_date: '2026-10-18 17:17'
labels: []
milestone: m-0
dependencies:
  - TASK-005
  - TASK-006
  - TASK-007
  - TASK-008
documentation:
  - backlog/docs/doc-0001-PRD.md
priority: high
type: task
ordinal: 9000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The user games on the same PC and wants the stack running only when started on purpose: one command up, one down, no boot auto-start (PRD F4, N3, deliverable 4). Optional extras (game-detection guard, GPU power limit) are decided while writing these (O8).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 `ai-up` starts llama-swap and LiteLLM with secrets injected and waits for health checks
- [x] #2 `ai-up` reports healthy in under 2 minutes; the measured time is recorded
- [x] #3 `ai-up` run while the stack is already up does not start duplicates
- [x] #4 `ai-down` stops all stack processes and VRAM is near idle within seconds per `nvidia-smi`; before/after numbers are recorded
- [x] #5 Nothing in the stack starts at boot
- [x] #6 Decision on the game guard and power limit is recorded (O8)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Results (2026-10-18):

Built scripts/ai-up.ps1 [-Warm] [-NoTailnet] [-Force] [-MinFreeVramMiB] [-GamePathPattern], scripts/ai-down.ps1 and scripts/lib/stack.ps1. ai-up: checks the install and the stored key, refuses when the stack is partly running or a stack port is taken, runs the game/VRAM guard, starts llama-swap (-listen 127.0.0.1:8080, logs in D:\local-ai\logs), starts the router via start-litellm.ps1, verifies /health and an authenticated /v1/models, publishes port 4000 with tailscale serve (skipped with -NoTailnet or when Tailscale is signed out), writes run\stack.json (idle VRAM baseline); cleans up by calling ai-down if any start step fails. ai-down: unpublishes the tailnet port, stops router, llama-swap and (after a grace period) llama-server, only processes under D:\local-ai or running litellm (a foreign listener is left alone with a warning), then waits for VRAM to return to the recorded baseline.

Measured (RTX 5090): ai-up healthy in 15.5 s, 12.7-13 s on later cold starts, 21.5 s with -Warm (model loads in 8.3 s); a second ai-up starts nothing (process counts unchanged: 1 llama-swap, 1 router); after a request the model is loaded (23,452 MiB used); ai-down: 23,452 -> 2,147 MiB in 2.6 s, no llama-server, llama-swap or router left, tailnet publishing off; ai-down on a clean machine: "Nothing was running". Guards: -MinFreeVramMiB 40000 -> refused (30,041 MiB free); a process matching the game pattern -> refused and nothing started; -Force overrides; only llama-swap running -> refused with "run ai-down"; a foreign TcpListener on 8080 -> ai-up refused and ai-down left it alive. Nothing at boot: 0 scheduled tasks, 0 Run-key entries, 0 Startup-folder entries, 0 services for the stack (the Tailscale service itself starts with Windows, as noted in decision-006). Bugs found and fixed while testing: a shutdown race (judging llama-server while it was exiting), and a variable-name collision between the library default pattern and the -GamePathPattern parameter. Two of my first test attempts were invalid (Store-app Notepad exits its launcher process; a stack left running made the next test see "already running").

O8 decided in decision-007; doc-002 updated. Test scripts are in D:\local-ai (outside the repo).

Limits: the path check misses games installed outside the listed folders (the free-VRAM check still catches them); no game was actually launched, the guard was exercised with stand-in processes; the manual power-limit speed cost is unmeasured.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
scripts/ai-up.ps1 and scripts/ai-down.ps1 (with scripts/lib/stack.ps1) start and stop the whole stack on demand. ai-up checks the install and stored key, refuses over a game or low VRAM or a half-running stack, starts llama-swap and the router on loopback with the key injected, verifies health and an authenticated /v1/models, publishes port 4000 on the tailnet and cleans up on failure; ai-down unpublishes, stops the router, llama-swap and llama-server (only stack processes) and waits for VRAM to return to idle. Measured: healthy in 12.7-15.5 s (21.5 s with -Warm), a second ai-up starts nothing, ai-down frees 23.4 GB -> 2.1 GB in 2.6 s, nothing registered to start at boot. O8 decided in decision-007 (game guard yes, power limit no). doc-002 updated.

Risks/follow-ups (not created as tasks): the game-path check misses games outside the listed folders (the free-VRAM check still catches them) and no real game was launched; the manual power-limit speed cost is unmeasured; the scripts assume the install paths and llama.cpp/llama-swap folder names from the pins; a crashed ai-up leaves nothing running but a stale run\stack.json can remain until the next ai-down.
<!-- SECTION:FINAL_SUMMARY:END -->
