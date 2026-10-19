---
id: TASK-020
title: Add Qwen3.6 27B Q6_K as a second local model with a larger context window
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-19 12:11'
updated_date: '2026-10-19 13:51'
labels: []
dependencies: []
references:
  - scripts/versions.psd1
  - config/llama-swap.yaml
  - config/claude-settings.json
  - scripts/ai-up.ps1
  - config/litellm.yaml
  - scripts/install.ps1
  - README.md
  - >-
    backlog/tasks/task-015 -
    Handle-parallel-tool-results-overflowing-the-128K-window.md
documentation:
  - backlog/docs/doc-002 - PRD-changes-and-implementation-log.md
priority: medium
ordinal: 20000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
local-coder runs Qwen3.6 27B at Q4_K_M with a 128K context and uses about 23.4 GB of the 32 GB card with the model loaded (decision-004, TASK-010). The user wants to try the higher-quality Q6_K quant of the same model next to it, not instead of it: local-coder and local-light stay as they are, and the Q6_K becomes one more entry in the model list, served by llama-swap and routed through LiteLLM, so it can be picked in /model and compared in daily use.

Estimates from bits per weight, not measured: Q6_K weights about 22.1 GB, about 29 GB in use at 128K, about 3 GB spare. The KV cache is cheap on this hybrid model (4.35 GiB for 128K, about 1.1 GiB per extra 32K), so 160K looks comfortable and 192K tight. A larger window matters because an interactive Claude Code session starts at about 67K tokens and compaction fires at 70% of the window (TASK-015), leaving only about 25K of working room at 128K.

Constraints known now: the two quants cannot be in VRAM together, so llama-swap has to unload one to load the other, and two sessions on different local entries would make it swap on every request. CLAUDE_CODE_MAX_CONTEXT_TOKENS is a single value in config/claude-settings.json that applies to both local entries, so a larger window on one entry needs a per-model setting in Claude Code, or both servers on the same window; a Claude Code window larger than the server context ends turns with a context-exceeded 400 (TASK-010). The ai-up free-VRAM guard (22000 MiB) was sized for the Q4_K_M. The GPU is shared with the desktop, and on Windows a CUDA allocation beyond VRAM can fall back to system memory and show up as a slowdown instead of an error. This is a narrow comparison on the same model, not a reopening of the skipped bake-off (doc-002).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 install.ps1 installs and hash-verifies the Q6_K GGUF next to the Q4_K_M, its SHA-256 is pinned in scripts/versions.psd1, and -CheckOnly reports both models
- [ ] #2 The Q6_K is a separate entry in config/llama-swap.yaml and config/litellm.yaml and a separate row in the /model picker on the PC and the Mac; local-coder and local-light keep the Q4_K_M model and their 128K window (Claude Code has a per-model compaction window, so option 1 was not needed; the compaction percentage they share was changed by user decision, criterion 9)
- [x] #3 Q6_K at 128K is measured against the Q4_K_M baseline (23.4 GB in use, 56 tok/s generation and 2,345 tok/s prompt processing at a ~94K-token prompt): VRAM in use, generation and prompt-processing speed
- [x] #4 At least one larger window for the Q6_K entry (160K, and 192K if the headroom allows) is measured with a near-full prompt; the chosen value leaves at least 1 GB of VRAM free with the desktop idle and shows no slowdown from system-memory fallback
- [x] #5 Switching between the Q4_K_M and Q6_K entries works in both directions: the other model is unloaded first, VRAM never holds both, and the switch time is measured
- [x] #6 The TASK-013 ts-demo multi-step edit task completes with the Q6_K entry, tool calls succeeding
- [x] #7 The ai-up free-VRAM guard covers the larger model, and doc-002, the README (models, pinned versions, switching delay) and decision-004 or a new decision record the result, including whether the user keeps the entry
- [x] #8 For every local entry, the auto-compact window Claude Code uses (effectiveWindow in its debug log) fits inside that server context, and a near-full prompt on each entry ends without a context-exceeded error
- [x] #9 CLAUDE_AUTOCOMPACT_PCT_OVERRIDE (one value for all entries) is chosen so that the reproduction that really passed in TASK-015, 8 parallel full Reads, passes on each local entry (its 16-Read passes had read one line per file); a higher value is also tried and its result recorded, and it is recorded that the override can only lower the default threshold (effective window minus 13K)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Research (done): Q6_K upstream (unsloth) 22,523,238,624 bytes, SHA-256 ec1805fe...; the Q4_K_M pin matches upstream. Claude Code 2.1.302: CLAUDE_CODE_MAX_CONTEXT_TOKENS is one global window for unrecognised models; modelSettings.<model>.autoCompactWindow sets a compaction window per model (verified: local-coder at 131072 gives effectiveWindow 111072, local-light without an entry follows the 163840 global); the pct override only lowers the threshold (min(floor(e*pct), e-13000), e = window - 20000); measured threshold today 77,750 tokens (doc-002 says ~92K, wrong). So criterion 2 condition is false: local-coder and local-light stay at 128K via modelSettings.
2. Install: versions.psd1 gets a model list (Q4_K_M, Q6_K); install.ps1 loops over it (size check, resumable download, SHA-256) and sums missing model sizes in the free-space check; ai-up checks both model files. Run install.ps1 to fetch the Q6_K, then -CheckOnly.
3. Serve: llama-swap entry local-coder-q6 (same flags as local-coder, own ctx), LiteLLM entry, picker row Local Coder Q6, modelSettings pinning local-coder and local-light to 131072, global CLAUDE_CODE_MAX_CONTEXT_TOKENS = the Q6_K server context.
4. Measure directly against llama-swap, like decision-004: Q4_K_M baseline again today, Q6_K at 128K, 160K and 192K with a ~94K and a near-full prompt; VRAM used and free with the model loaded; system-memory fallback judged by generation speed at a near-full prompt vs short prompt.
5. Switching both ways: VRAM sampled every 0.5 s across the switch, time to first token after the switch.
6. Compaction: TASK-015 16-Read reproduction on local-coder and local-coder-q6 at 70% and at one higher value; debug-log effectiveWindow per entry; near-full prompt per entry.
7. ts-demo multi-step edit (TASK-013 task) with local-coder-q6.
8. ai-up guard: refuse below the Q4_K_M need as today, warn when free VRAM is below the Q6_K need (sized from step 4).
9. Record in doc-002 (including the 92K correction), README, a new decision superseding parts of decision-004; stop for the user decision on keeping the entry, the window and the pct.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Measurements (bench llama-swap on 127.0.0.1:8081, D:\local-ai\scratch\q6\, every prompt starts with a fresh GUID). Q4_K_M 128K today: 22,928 MiB in use (llama-server 21,354 dedicated, 248 shared), short tg 76.9, 94K pp 2,385 / tg 56.8, 128K prompt pp 1,976 / tg 51.0. Q6_K 128K: 27,964 MiB (26,482 dedicated), short tg 61.6, 94K pp 2,184 / tg 47.8, 128K pp 1,831 / tg 44.2. Q6_K 160K: 29,261 MiB at a 160,935-token prompt (27,730 dedicated, 280 shared), 94K tg 48.1, full prompt pp 1,594 / tg 41.0, 108 s; about 2.9 GB free. Q6_K 192K: 30,520 MiB at 193,950 tokens (28,980 dedicated, 312 shared), 94K tg 48.1, full prompt pp 1,441 / tg 37.9, 142 s; about 1.7 GB free. No system-memory fallback at any window: 94K speed identical across windows, shared usage grows 32 MiB per 32K step (pinned buffers). Cold first load of the Q6_K 27 s, later 18 s.
Install: install.ps1 fetched and hash-verified the Q6_K (1021 s), -CheckOnly lists both models [ok].
Real stack: router /v1/models lists local-coder-q6; Claude Code effectiveWindow local-coder 111072, local-light 111072, local-coder-q6 143840 (repo settings). Switching through the router: Q4->Q6 13.1 s, Q6->Q4 11.5-12.1 s, local-light after local-coder 0.3 s; 185 samples at 0.5 s: never more than one llama-server, VRAM back to idle (1,544 MiB) before each load, peak 29,281 MiB. Q6 llama-server listens on 10002 (llama-swap assigns ports in config order): ai-up pre-check and ai-down now cover 10002; tested with Q6 loaded (29,280 -> 1,533 MiB in 3 s) and a foreign listener on 10002 (refused).
ts-demo with local-coder-q6: done in 61 s, 10 tool calls (one wrong-path Read), edits correct, npm test 5/5 (rerun by me); repo reset to fdcc3ad.
Overflow: 16 parallel full Reads (about 128K tokens of results in one step) fail on both entries at 70% and 80% with a 400 ContextWindowExceededError (request ~177K tokens); Claude Code estimated 113,851 tokens before its compaction, so its estimate undercounts this test text by about 55%, and the LiteLLM 400 is not treated as prompt-too-long, so reactive compaction does not recover. The TASK-015 16-Read passes (ovf16B/C) had read one line per file (limit=1); its real passes were 8 full Reads. 8 parallel full Reads pass on both entries at 70%, 80% and 90%. Thresholds: local-coder 77,750 / 88,857 / 98,072 (90% is capped at the default), local-coder-q6 100,688 / 115,072 / 129,456. ai-up warns below 28,500 MiB free for the Q6 entry (tested with the threshold raised; silent at 30,655 MiB free).

User decisions 2026-10-19: keep local-coder-q6, 160K, CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=80 (set in config/claude-settings.json; all three entries answer with it, effectiveWindow unchanged). Criterion 2 condition resolved: Claude Code has modelSettings.<model>.autoCompactWindow, so local-coder stays at 128K (option 1 not needed). Criterion 8 evidence: effectiveWindow per entry inside its server context; near-full prompts at the server window (128,450 tokens on the Q4_K_M at 128K, 160,935 on the Q6_K at 160K) succeed; local-light shares the Q4_K_M server. decision-004: the backlog CLI (1.54.0) can only set a decision title and status, so instead of a new decision with an empty body, decision-004 status now says it is partly superseded by TASK-020 and doc-002 holds the record. Criterion 2 stays open until the user sees Local Coder Q6 in an interactive /model on the PC, and on the Mac after a pull.

User check 2026-10-19: Local Coder Q6 is listed in /model on the PC (it did not answer because the stack was down at the time). The Mac check needs the pushed config and a git pull there.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added Qwen3.6 27B Q6_K as a third local entry, local-coder-q6, next to the unchanged Q4_K_M local-coder and local-light. install.ps1 now installs a list of hash-pinned models; llama-swap serves the Q6_K on 127.0.0.1:10002 with a 160K window; LiteLLM routes it; the picker has a Local Coder Q6 row. Claude Code gets one global window (163840) and per-model compaction windows (modelSettings.local-coder/local-light.autoCompactWindow = 131072), checked in its debug log. Measured: Q6_K is 15-20% slower (160K: 61.9 tok/s short, 48.1 at 94K, 41.0 at a 161K prompt), holds 27.7 GB, leaves 2.9 GB free, no system-memory fallback; 192K was measured and rejected (1.7 GB free, 37.9 tok/s at full). Switching takes 11.5-13 s and never holds both models. ts-demo passes on the Q6_K. ai-up warns below 28,500 MiB free; ai-up and ai-down cover port 10002. Compaction raised from 70% to 80% by user decision after measuring that the percentage applies to window minus 20K and can only move compaction earlier: local-coder now compacts at about 88.9K instead of 77,750 (doc-002 had ~92K), local-coder-q6 at about 115.1K. TASK-015 conclusion corrected: its 16-Read passes read one line per file; 8 full Reads pass at 70/80/90% on both entries, 16 full Reads (~128K tokens in one step) fail at any value because Claude Code undercounts the text and does not recover from the LiteLLM 400 (follow-up task). README, doc-002 and decision-004 status updated. Open: the interactive /model check on the PC and the Mac (criterion 2).
<!-- SECTION:FINAL_SUMMARY:END -->
