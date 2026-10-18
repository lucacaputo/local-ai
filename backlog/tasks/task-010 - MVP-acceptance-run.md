---
id: TASK-010
title: MVP acceptance run
status: Done
assignee:
  - '@claude'
created_date: '2026-10-18 14:13'
updated_date: '2026-10-18 20:52'
labels: []
milestone: m-0
dependencies:
  - TASK-004
  - TASK-009
documentation:
  - backlog/docs/doc-0001-PRD.md
priority: medium
type: task
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Milestone m-0 is done only when its "Done when" criteria hold on the real stack started by the scripts, not on the hand-built spike setup.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Stack started with `ai-up` is healthy in under 2 minutes, and `ai-down` leaves VRAM near idle
- [x] #2 `/model` on the PC lists Claude and local models, and each one completes a request
- [x] #3 A multi-step edit task completes with `local-coder` with tool calls succeeding
- [x] #4 Model unloads after the idle `ttl`
- [x] #5 No secrets are present in the repo or in plaintext config
- [x] #6 Pinned versions that passed are recorded (O10)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Acceptance run on the real stack (ai-up). #1: healthy in 19.9 s and 21.9 s; ai-down VRAM 23238 -> 1982 MiB (idle 2025). #2: claude -p PONG from local-coder, local-light and sonnet (modelUsage confirms each); interactive /model on the PC lists the standard Claude models plus Local Coder and Local Light, and local-coder answers in a session. FOUND: with -c 131072 and --parallel 2 each slot had only 64K, so Claude Code's ~67K-token prompt failed with exceed_context_size_error; fixed with -kvu in config/llama-swap.yaml (n_ctx now 131072, VRAM 23.4 GB unchanged), user re-ran the session OK. #3: ts-demo edit task (discount field, count(), tests, npm test) done in 14 turns, 6 tests pass, 9 tool calls ok and 4 errors, all wrong-path first Reads that the model recovered from. #4: log 'Unloading model, TTL of 300s reached', VRAM 2002 MiB afterwards. #5: router key value not found in worktree or git history, pattern scan of tracked files clean, no .env/.key/.pem tracked. #6: versions recorded in doc-002.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
MVP acceptance run passed on the stack started by ai-up. Healthy in ~20 s; ai-down returns VRAM to idle; /model lists Claude plus Local Coder/Light and each answers; multi-step edit task completes with local-coder (6 tests pass); model unloads after the 300 s ttl; no secrets in repo or history; passing versions recorded in doc-002. Found and fixed one defect: --parallel 2 split the 128K context into 64K slots, fixed with -kvu in config/llama-swap.yaml.
<!-- SECTION:FINAL_SUMMARY:END -->
