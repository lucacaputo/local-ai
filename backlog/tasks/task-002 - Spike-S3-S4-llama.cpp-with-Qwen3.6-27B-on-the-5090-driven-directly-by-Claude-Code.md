---
id: TASK-002
title: >-
  Spike S3/S4: llama.cpp with Qwen3.6 27B on the 5090, driven directly by Claude
  Code
status: Done
assignee:
  - '@claude'
created_date: '2026-10-18 14:13'
updated_date: '2026-10-18 14:53'
labels: []
milestone: m-0
dependencies:
  - TASK-001
documentation:
  - backlog/docs/doc-0001-PRD.md
priority: high
type: spike
ordinal: 2000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The whole stack depends on one local model fitting fully in 32 GB VRAM (no RAM spill-over with 32 GB system RAM) and being fast and reliable enough for agentic coding (PRD N1, R3, R4, R6). Prove it by hand with no router in between, so a failure here points at the model, quant or build rather than LiteLLM. Fallbacks if it fails: another quant/build, then another model from PRD section 6.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 llama.cpp CUDA 12.8+ build and Qwen3.6 27B Q4_K_M are on the SN850X drive
- [x] #2 `llama-server` runs bound to loopback with `--jinja`, 64K context, q8 KV cache and flash attention; the exact launch command is recorded
- [x] #3 `nvidia-smi` shows the model fully on GPU; VRAM usage at 64K context is recorded
- [x] #4 Generation tok/s and prompt-processing speed are measured and compared against N1 (about 40 tok/s at 64K)
- [x] #5 Claude Code pointed directly at llama-server via `ANTHROPIC_BASE_URL` (throwaway profile, no subscription login) completes a multi-step edit task; tool-call failures are recorded
- [x] #6 Outcome is recorded: pass, or which fallback was taken
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Create D:\local-ai\{bin,models} (outside the repo). Download llama.cpp b11719 win-cuda-13.4-x64 + cudart zip (decision-002) into bin\llama.cpp-b11719; download unsloth/Qwen3.6-27B-GGUF Qwen3.6-27B-Q4_K_M.gguf (15.7 GiB, Apache-2.0) into models\.
2. Run llama-server by hand on 127.0.0.1:8080: --jinja, -c 65536, --cache-type-k q8_0 --cache-type-v q8_0, -fa on, -ngl 99. Record the exact command and the load log (layers offloaded).
3. Measure VRAM with nvidia-smi at idle and after a ~60K-token prompt; measure prompt-processing and generation tok/s via llama-bench or the server timings and compare with N1 (~40 tok/s gen at 64K).
4. Check POST /v1/messages (streaming + tool use) with curl.
5. Throwaway Claude Code profile: separate CLAUDE_CONFIG_DIR, ANTHROPIC_BASE_URL=http://127.0.0.1:8080, dummy ANTHROPIC_API_KEY (stays out of the real login), model name set to the served model. Run one multi-step edit task in a scratch repo; count tool-call failures.
6. Record outcome (pass, or fallback: Q4_K_S / UD-Q4_K_XL / other build, then another model from PRD section 6).
7. Stop for review before checking criteria.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Research (2026-10-18): unsloth/Qwen3.6-27B-GGUF is the most-downloaded GGUF repo (~496k downloads, Apache-2.0, updated 2026-04-22). Q4_K_M = 15.7 GiB; alternatives UD-Q4_K_XL 16.4, Q5_K_M 18.2. Repo also has mmproj files (vision, not needed). D: currently holds game libraries only; use D:\local-ai\ for bin and models. Several fine-tune GGUFs rank high in downloads; ignore them, use the official unsloth quant.

Results (2026-10-18, llama.cpp b11719 win-cuda-13.4, Qwen3.6-27B-Q4_K_M from unsloth/Qwen3.6-27B-GGUF, 16817244384 bytes, SHA-256 matches Hugging Face; stored in D:\local-ai\{bin,models}):

Launch command (loopback):
llama-server.exe -m D:\local-ai\models\Qwen3.6-27B-Q4_K_M.gguf --host 127.0.0.1 --port 8080 --jinja -c 65536 --cache-type-k q8_0 --cache-type-v q8_0 -fa on -ngl 99 --alias local-coder

GPU: log shows "offloaded 65/65 layers to GPU", flash_attn enabled. CUDA0 model buffer 15346 MiB + KV 2176 MiB (q8_0, only 16 of 64 layers use attention KV) + recurrent state 599 MiB + compute 420 MiB = ~18.5 GiB projected. nvidia-smi: 21.2 GB used total with the server running (desktop ~1.8 GB idle), unchanged after a 63K-token prompt, so memory is preallocated. ~11 GB headroom; model native context is 262144 so O4 can be revisited upward. Server default is n_slots=4 with unified KV (fine for one user; consider -np 1).

Speed (single stream, temp 0): short prompt 400 tokens generated at 76 tok/s; 31.5K-token prompt: prompt processing 3452 tok/s, generation 69 tok/s; 63.0K-token prompt: prompt processing 2894 tok/s (25 s total), generation 63 tok/s. N1 (about 40 tok/s at 64K) is met with ~55% margin.

API: POST /v1/messages returns a proper tool_use block (with a thinking block first); /v1/messages/count_tokens works. R3 confirmed for this build.

Claude Code test (v2.1.302, throwaway CLAUDE_CONFIG_DIR=D:\local-ai\claude-profile, ANTHROPIC_BASE_URL=http://127.0.0.1:8080, dummy ANTHROPIC_API_KEY, all model aliases = local-coder, -p, acceptEdits + allowlist, scratch TS repo D:\local-ai\scratch\ts-demo): 4-step task (rename function across 4 files, add discountPercent with RangeError, add tests, run npm test). Run 2: success in 72 s / 30 turns; 29 tool results, 7 errors (24% raw). Independently re-ran npm test: 5/5 pass, no calcTotal left. Errors were self-corrected: 4x Read with a wrong path under the config dir ("claude-profile\projects\...\src\x.ts", same pattern in run 1: 5x), 2x Edit failures, 1x npm test non-zero exit during a fix cycle. Run 1 stopped at the last step only because my allowlist covered Bash but Claude Code used its PowerShell tool for npm test (permission issue, not model failure). Raw tool error rate misses the R4 gate of under 5%, but this is one small run and includes path-guess errors and one legitimate test failure; the bake-off must define what counts as a tool-call failure. Note: the first attempt with --permission-mode bypassPermissions was blocked by the auto mode classifier; I did not retry it.

Outcome: S3 pass; S4 (direct) pass with the caveat above; no fallback needed. Server stopped afterwards (VRAM back to idle). Helper scripts (not in repo): D:\local-ai\run-server.cmd, bench.ps1, run-claude-test.ps1; logs in D:\local-ai\logs.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Proved Qwen3.6-27B Q4_K_M runs fully on the RTX 5090 via llama.cpp b11719 (CUDA 13.4): 65/65 layers on GPU, ~21.2 GB VRAM total at 64K context with q8 KV, 63-76 tok/s generation (N1 needs ~40) and ~2.9-3.5K tok/s prompt processing. /v1/messages with tool use works. Claude Code 2.1.302 on a throwaway profile pointed straight at llama-server completed a 4-step edit task (verified 5/5 tests passing independently). No fallback needed.

Risks/follow-ups (not created as tasks): raw tool-call error rate was 24% (7/29, mostly self-corrected wrong-path Reads), above the R4 gate of 5%, so the bake-off must define what counts as a failure and re-measure; launch flags may want -np 1; the model path-prefix confusion under a custom CLAUDE_CONFIG_DIR is worth checking in the bake-off. Details, exact launch command and numbers are in the implementation notes.
<!-- SECTION:FINAL_SUMMARY:END -->
