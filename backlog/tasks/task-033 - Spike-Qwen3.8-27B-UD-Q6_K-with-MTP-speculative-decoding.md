---
id: TASK-033
title: 'Spike: Qwen3.8-27B UD-Q6_K with MTP speculative decoding'
status: To Do
assignee: []
created_date: '2026-10-21 20:45'
labels: []
milestone: m-4
dependencies: []
references:
  - 'https://huggingface.co/unsloth/Qwen3.8-27B-GGUF'
  - 'https://github.com/sudoingX/qwen38-mtp'
  - 'https://github.com/ggml-org/llama.cpp/issues/27107'
documentation:
  - backlog/docs/doc-002 - PRD-changes-and-implementation-log.md
priority: high
type: spike
ordinal: 33000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Local generation on the Qwen3.6 Q6_K entry runs at about 62 tok/s short and 41 tok/s near a full 160K prompt (TASK-020). MTP speculative decoding is reported to roughly double output speed on an RTX 5090 (61 -> 135 tok/s at Q6_K, 128K), and `--spec-type draft-mtp` is already in the pinned llama.cpp b11719. Our Qwen3.6 GGUFs carry no MTP head, while unsloth Qwen3.8-27B-UD-Q6_K.gguf (21.98 GB) does (`blk.64.nextn.*`), and Qwen3.8 has the same config as Qwen3.6. Open questions: the Qwen3.8 chat template has hard assertions that break Claude Code on llama-server (llama.cpp #27107); MTP needs about 1.1 GB more VRAM, and the Q6_K entry already uses 29.3 of 32.6 GB at 160K; the MTP gain shrinks with concurrent requests, and we run `--parallel 2` (TASK-005: with one slot a second request waited 8.6 s instead of 2.4 s). The user decides the slot count from the numbers.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Qwen3.8-27B-UD-Q6_K.gguf is downloaded with a verified hash and served by llama-swap as a trial entry; the existing Qwen3.6 entries are unchanged
- [ ] #2 Claude Code through the router completes the ts-demo task on the trial entry; if the stock chat template fails, the patched template used, its source and the change are recorded
- [ ] #3 VRAM, generation speed (short, ~94K and near-full prompt) and prompt processing are measured as in TASK-020, with MTP off and with draft lengths 2, 3 and 4, at --parallel 1 and 2, plus the MTP acceptance rate
- [ ] #4 The largest window that fits with MTP and keeps about 1.5 GB for the desktop is found, and generation at a near-full prompt is checked against N1 (about 40 tok/s)
- [ ] #5 Results, recommended flags and the slot-count trade-off are recorded in doc-002 for the user to choose
<!-- AC:END -->
