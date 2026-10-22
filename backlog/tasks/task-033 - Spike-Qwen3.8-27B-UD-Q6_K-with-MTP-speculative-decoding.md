---
id: TASK-033
title: 'Spike: Qwen3.8-27B UD-Q6_K with MTP speculative decoding'
status: Done
assignee:
  - '@claude'
created_date: '2026-10-21 20:45'
updated_date: '2026-10-22 05:12'
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
- [x] #1 Qwen3.8-27B-UD-Q6_K.gguf is downloaded with a verified hash and served by llama-swap as a trial entry; the existing Qwen3.6 entries are unchanged
- [x] #2 Claude Code through the router completes the ts-demo task on the trial entry; if the stock chat template fails, the patched template used, its source and the change are recorded
- [x] #3 VRAM, generation speed (short, ~94K and near-full prompt) and prompt processing are measured as in TASK-020, with MTP off and with draft lengths 2, 3 and 4, at --parallel 1 and 2, plus the MTP acceptance rate
- [x] #4 The largest window that fits with MTP and keeps about 1.5 GB for the desktop is found, and generation at a near-full prompt is checked against N1 (about 40 tok/s)
- [x] #5 Results, recommended flags and the slot-count trade-off are recorded in doc-002 for the user to choose
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Research (done): unsloth Qwen3.8-27B-UD-Q6_K.gguf is 21,983,677,344 bytes, SHA-256 c9c20681...cd436 (HF LFS), header carries blk.64.nextn.* (MTP head inside the file, no draft file needed). Qwen/Qwen3.8-27B config.json identical to Qwen3.6-27B. b11719 has --spec-type draft-mtp, --spec-draft-n-max, --spec-draft-p-min. D: has 136 GB free.
2. Install: add the file to the model list in scripts/versions.psd1 under a trial name (local-coder-38), run install.ps1 (download, size and hash check), then -CheckOnly.
3. Bench with the stack down, on a bench llama-swap at 127.0.0.1:8081 as in TASK-020. Extend bench.ps1: a prompt built from real source files (the repeated sentence would inflate MTP acceptance), a ~1,000-token code answer, the draft acceptance from the response timings. Matrix at 160K: Qwen3.6 Q6_K and Qwen3.8 with MTP off, Qwen3.8 with n-max 2, 3 and 4 at --parallel 1; the best n-max at --parallel 2, alone and with a second request arriving mid-generation (TASK-005 style). Then 128K, 160K and 192K with the best setting: VRAM, desktop headroom, near-full prompt speed against N1.
4. Serve the trial entry through the real stack: config/llama-swap.yaml entry with the flags from step 3, LiteLLM entry, /model picker row and modelSettings window in config/claude-settings.json; ai-up pre-check and ai-down cover its port (10003).
5. Claude Code through the router: ts-demo on the trial entry, PC first. If the stock chat template fails (llama.cpp #27107), write our own patch in config/ that removes only the hard raise_exception assertions, and record the diff.
6. Record results, recommended flags and the slot-count trade-off in doc-002; stop for the user to choose slot count and window.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Install: Qwen3.8-27B-UD-Q6_K.gguf added to versions.psd1 as local-coder-38; install.ps1 downloaded it (about 18 MB/s) and verified size and SHA-256; -CheckOnly lists all three models [ok]. ai-up pre-check and ai-down now cover port 10003.
Bench (D:\local-ai\scratch\q38): real LiteLLM proxy source as long prompts, ~1,200-token code answers, Qwen thinking sampling (temp 1.0, top_p 0.95, top_k 20), median of 3. PowerShell 5.1 sent the source (non-ASCII) as non-UTF-8 and llama-swap relayed the 400 with status 200; bodies now go as UTF-8 bytes and an error body throws.
Baseline Qwen3.6 Q6_K 160K --parallel 2 (production): load 16.1 s, VRAM 29,438-29,487 MiB; short code 61.9 tok/s, short thinking 61.9; 98,301-token prompt pp 2,075 / tg 47.5; 161,494-token prompt pp 1,571 / tg 40.8 (132.5 s); concurrent: main 21.8 s at 55.2 tok/s, second request (5.8K prompt, 3 s later) 3.8 s.
GGUF chat template differs from Qwen/Qwen3.8-27B upstream: unsloth merges leading system/developer messages, drops the "No user query found" assertion, and adds assertions refusing tool-call arguments that are not a mapping (a non-empty JSON string raises). 11 raise_exception calls remain.

Qwen3.8 matrix at 160K (tg tok/s short code / 94K / 161K prompt; acceptance; VRAM with the model loaded; concurrent = main 1,200-token answer, second 5.4K-token request 3 s later):
- off p2: 63.5 / 49.1 / 41.7; 28,516 MiB; pp 2,179 at 94K, 1,610 at 161K; concurrent main 22.5 s, second 3.1 s
- off p1: 64.5 / 49.7 / -; 28,372 MiB; concurrent main 23.1 s, second 20.1 s (queued)
- n2 p1: 131.3 / 86.0 / 67.0; acc 0.85-0.88; 30,229-30,263 MiB; concurrent main 13.5 s, second 10.5 s
- n2 p2: 132.1 / 87.5 / -; acc 0.88; 30,677-30,709 MiB; concurrent main 15.7 s, second 4.5 s
- n3 p1: 149.0 / 100.7 / 80.7; acc 0.79-0.83; 30,379-30,413 MiB; concurrent main 12.1 s, second 9.0 s
- n3 p2: 152.7 / 91.6 / -; acc 0.70-0.83; 30,977-31,001 MiB; concurrent main 15.4 s, second 4.9 s
- n4 p1: 157.0 / 104.5 / 79.0; acc 0.69-0.76; 30,424-30,529 MiB; concurrent main 11.9 s, second 8.9 s
- n4 p2: 155.3 / 103.5 / -; acc 0.73-0.75; 31,138-31,168 MiB; concurrent main 10.5 s, second 3.5 s
Thinking output (reasoning_effort low) speeds up like code: n2 132.1, n3 147.4, n4 155.5. Prompt processing with MTP about 5% lower (2,039-2,073 at 94K). MTP adds about 1.9 GB VRAM at p1, a second slot about 0.6 GB more. Draft 3 chosen for the window round: same speed as 4 at a full prompt, higher acceptance.

Window round (draft 3): 128K p1 28,794 MiB, near-full 87.0 tok/s; 128K p2 29,392 MiB, 85.1; 160K p1 30,413 MiB, 80.7; 160K p2 31,001 MiB, 78.8 (pp 1,535); 192K p1 31,746 MiB (0.9 GB free), 70.4. 160K is the largest window with about 1.5 GB left for the desktop.
Trial entry in the real stack: config/llama-swap.yaml local-coder-38 (draft 3, 160K, --parallel 2, port 10003), LiteLLM entry, /model row Local Coder 3.8, global 163840 window applies; ai-up warns below 30,200 MiB free (Q38MinFreeVramMiB).
Claude Code ts-demo: first run failed on the first request with 500 "System message must be at the beginning." from the unsloth template (no tool ran). A harness slip in that run: git is not on the Windows PATH, the clone failed and claude -p started in the repo itself; it made no tool calls and git status showed only my edits. cc.ps1 now refuses to run unless the clone exists (clones are made from WSL). Fix: config/qwen3.8-chat-template.jinja = the GGUF template with that one raise replaced by a system turn; llama-swap --chat-template-file ${env.LOCAL_AI_REPO}\config\...; ai-up sets LOCAL_AI_REPO. Rerun: 74 s, 12 tool calls, 0 tool errors, first Reads at the right path, 7/7 tests.
Results in doc-002 section "Qwen3.8 with MTP, trial entry (TASK-033, m-4)". Waiting for the user: slot count (1 or 2) and window.

User decision (2026-10-22): keep 2 slots (--parallel 2 -kvu) and the 160K window; the trial entry already runs this setup, so no config change.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Qwen3.8-27B UD-Q6_K with MTP speculative decoding (draft 3) is in the stack as the trial entry local-coder-38: 160K window, 2 slots, about 31.0 GB VRAM. Output speed is about 150 tok/s on short answers and 79 tok/s at a full 160K prompt, against 62 and 41 for Qwen3.6 Q6_K; prompt processing is about the same. Claude Code ran ts-demo through the router on it in 74 s with 12 tool calls, no tool errors and 7/7 tests. The GGUF's chat template rejected a later system message (llama.cpp #27107), so config/qwen3.8-chat-template.jinja holds a patched copy and ai-up sets LOCAL_AI_REPO for it. ai-up warns below 30,200 MiB free and ai-down stops port 10003. Benchmarks are in doc-002. Follow-ups: quality check against Qwen3.6 (TASK-034) before it replaces anything; the trial entry has not been tried from the Mac yet.
<!-- SECTION:FINAL_SUMMARY:END -->
