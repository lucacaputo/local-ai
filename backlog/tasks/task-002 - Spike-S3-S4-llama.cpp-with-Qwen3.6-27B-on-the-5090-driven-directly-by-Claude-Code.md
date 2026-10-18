---
id: TASK-002
title: >-
  Spike S3/S4: llama.cpp with Qwen3.6 27B on the 5090, driven directly by Claude
  Code
status: To Do
assignee: []
created_date: '2026-10-18 14:13'
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
- [ ] #1 llama.cpp CUDA 12.8+ build and Qwen3.6 27B Q4_K_M are on the SN850X drive
- [ ] #2 `llama-server` runs bound to loopback with `--jinja`, 64K context, q8 KV cache and flash attention; the exact launch command is recorded
- [ ] #3 `nvidia-smi` shows the model fully on GPU; VRAM usage at 64K context is recorded
- [ ] #4 Generation tok/s and prompt-processing speed are measured and compared against N1 (about 40 tok/s at 64K)
- [ ] #5 Claude Code pointed directly at llama-server via `ANTHROPIC_BASE_URL` (throwaway profile, no subscription login) completes a multi-step edit task; tool-call failures are recorded
- [ ] #6 Outcome is recorded: pass, or which fallback was taken
<!-- AC:END -->
