---
id: TASK-005
title: 'llama-swap with local-coder, local-light and idle unload'
status: Done
assignee:
  - '@claude'
created_date: '2026-10-18 14:13'
updated_date: '2026-10-18 16:03'
labels: []
milestone: m-0
dependencies:
  - TASK-003
documentation:
  - backlog/docs/doc-0001-PRD.md
priority: high
type: task
ordinal: 5000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The GPU is shared with gaming, so model weights must load only when needed and leave VRAM after idle (PRD F5, N3). llama-swap also lets `local-light` exist as its own name, initially aliasing the coder, so a smaller model can be added later without client changes (O3).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 `config/llama-swap.yaml` defines `local-coder` with the launch flags proven in the S3 spike (at the 128K context from decision-004), and `local-light` as an alias
- [x] #2 llama-swap and llama-server bind to loopback only
- [x] #3 LiteLLM routes `local-coder` and `local-light` through llama-swap, and both work from Claude Code
- [x] #4 Model loads on first request and VRAM is released after the configured `ttl`; the measured unload is recorded
- [x] #5 Number of llama-server parallel slots (`--parallel` 1, 2 or 4) is chosen by comparing request latency with a background request running; the choice and numbers are recorded
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Download llama-swap v265 (windows_amd64, 21 MB) into D:\local-ai\bin\llama-swap-v265 (decision-002); check its CLI flags for the listen address.
2. Write config/llama-swap.yaml: local-coder (llama-server b11719 with the TASK-002 flags and -c 131072, --host 127.0.0.1, port from ${PORT}) with aliases [local-light], ttl for idle unload, paths via ${env.LOCAL_AI_ROOT} so nothing is hard-coded (decision-003).
3. Run llama-swap on 127.0.0.1:8080 by hand; verify the model is not loaded at start, loads on the first request (time it) and that VRAM is released after the ttl (nvidia-smi, measured).
4. Point config/litellm.yaml local-coder and local-light at llama-swap (same api_base :8080) and check both from Claude Code (-p) and that LiteLLM's Responses-API route works through llama-swap.
5. Slots: compare -np 1, 2, 4 with a Claude Code task running while background requests hit the server; record latency and choose.
6. Confirm listeners with netstat (127.0.0.1 only). Record results; stop for review.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
From TASK-004 (2026-10-18): use -c 131072 (128K) in the llama-server flags, not the 64K from TASK-002; measured 23.6 GB VRAM total, 56 tok/s at a 94K prompt. Claude Code is told the same window via CLAUDE_CODE_MAX_CONTEXT_TOKENS=131072.

Results (2026-10-18, llama-swap v265, llama.cpp b11719):

Config: config/llama-swap.yaml (validated with -validate): local-coder with the TASK-002 flags at -c 131072, --parallel 2, ttl 300, alias local-light, paths via ${env.LOCAL_AI_ROOT} (D:\local-ai), llama-server on --host 127.0.0.1 --port ${PORT} (10001+). IMPORTANT: llama-swap listens on ALL interfaces by default; it must always be started with -listen 127.0.0.1:8080. config/litellm.yaml now sends local-coder and local-light to llama-swap (openai/local-coder, openai/local-light, api_base http://127.0.0.1:8080/v1).

Lifecycle (ttl 300): model not loaded at start (VRAM 1.9 GB); first request via the alias local-light loaded it in 10.2 s (VRAM 23.6 GB); warm request 2.7 s; llama-server exited 306 s after the last request and VRAM returned to 2.0 GB; reload on the next request 10.1 s; stopping llama-swap also stops llama-server (VRAM 1.9 GB). The alias reuses the loaded process (local-light after local-coder: no second load). Listeners: only 127.0.0.1:8080 (llama-swap) and 127.0.0.1:10001 (llama-server).

Through the router (router -> llama-swap -> llama-server): claude -p --model local-coder and --model local-light both returned PONG, Claude Code reports window 131072 for both; the Responses-API route works through llama-swap.

Slots (direct requests against llama-swap, not a Claude Code run: 700-token generation plus a 5.4K-token request arriving 3 s later): np=1 background request 8.6 s (queued behind the main one), main 9.4 s (alone 9.1 s), VRAM 23.2 GB; np=2 background 2.4 s, main 10.8 s, 23.2 GB; np=4 background 2.4 s, main 10.8 s, 23.5 GB. Single-stream speed identical (77 tok/s). Chose --parallel 2: background/second requests do not wait, main slows ~1.7 s, less memory than 4. Caveat: Claude Code's small-model background calls normally go to Haiku on Anthropic, not to the local server, so contention only comes from subagents or a second session; I did not run a concurrent Claude Code session test.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
llama-swap v265 now fronts llama-server: config/llama-swap.yaml loads local-coder (Qwen3.6 27B Q4_K_M, 128K context, --parallel 2) on the first request, exposes local-light as an alias of the same process, and unloads after a 300 s idle ttl (measured: gone after 306 s, VRAM 23.6 GB -> 2.0 GB, reload 10.1 s). Only 127.0.0.1:8080 and 127.0.0.1:10001 listen. config/litellm.yaml sends both local models through llama-swap; claude -p works for both with a 131072 window. Slots chosen by direct-request comparison: 2 slots keep a background request at 2.4 s instead of 8.6 s at the cost of ~1.7 s on the main generation.

Risks/follow-ups (not created as tasks): llama-swap listens on all interfaces unless started with -listen 127.0.0.1:8080 (TASK-007/009 must enforce it); the slot test did not use a concurrent Claude Code session; LOCAL_AI_ROOT must be set by the launcher; llama-swap has an apiKeys option that could add a second auth layer later.
<!-- SECTION:FINAL_SUMMARY:END -->
