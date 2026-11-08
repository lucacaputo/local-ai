---
id: TASK-039
title: 'Spike: Qwen3.8 27B with the vision projector on the 32 GB card'
status: Done
assignee:
  - '@claude'
created_date: '2026-11-08 17:43'
updated_date: '2026-11-08 20:10'
labels: []
milestone: m-5
dependencies: []
references:
  - 'https://huggingface.co/bartowski/Qwen3.8-27B-GGUF'
documentation:
  - backlog/docs/doc-003 - PRD-Local-agent-for-non-coders.md
  - backlog/docs/doc-004 - Agent-stack-changes-and-decisions.md
priority: high
type: spike
ordinal: 39000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The agent reads screenshots and pages, so the model shared by the coding stack and the agents needs image input (doc-003 section 6, decision-013). Qwen3.8 27B reads images in llama.cpp with its vision projector (`--mmproj`, about 0.9 GB); some guides also set a minimum number of image tokens. Today's local-coder entry (decision-009: UD-Q6_K, MTP draft 3, 2 slots at 160K) takes 29.4 GB and the idle desktop leaves about 30.4 GB free, so the projector does not fit as is. Agents probably need less than 160K per slot, while more users need more slots. The user chooses the entry from the numbers.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The projector for the installed Qwen3.8 file is downloaded with a verified hash and served by llama-swap in a trial entry; the current local-coder entry is unchanged
- [x] #2 A web page screenshot and a scanned document page sent through the router get correct answers (text read, layout described, a button located), in Italian and in English
- [x] #3 VRAM, generation speed and prompt processing with an image are measured for at least 2 slots at a shorter window, 1 slot at 160K, and a smaller quant with 2-3 slots, with MTP on and about 1.5 GB kept for the desktop
- [x] #4 The effect of the image-token setting on reading small text and on prompt time is measured
- [x] #5 Results and a recommended 32 GB entry are recorded in doc-004 for the user to choose
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Download unsloth mmproj-F16.gguf (927,607,488 bytes, SHA-256 cbb841a9...4e43e from the HF API) to D:\local-ai\models and verify the hash. Add a trial entry local-coder-vision to config/llama-swap.yaml and config/litellm.yaml only (not Claude Code or OpenCode settings), today's local-coder flags plus --mmproj; local-coder unchanged.
2. First check: b11719 starts with --mmproj and --spec-type draft-mtp together, and MTP stays active on text and on requests with an image (draft acceptance in timings). If the build turns MTP off with a projector, stop and report: that changes every option.
3. Vision checks through the router, Italian and English: a screenshot of a fixture web page (text, layout, locate a button with coordinates), a scanned-looking document page (noise, slight rotation), a page with small text. Known answers, scored by hand.
4. Bench llama-swap on 127.0.0.1:8081 as in TASK-033 (stack down), bench.ps1 extended with an image request (time to first token, image tokens). Setups, all MTP draft 3, about 1.5 GB kept for the desktop:
   a. Q6, 2 slots, 160K, projector on CPU (--no-mmproj-offload, no VRAM cost)
   b. Q6, 2 slots, largest window that fits with the projector on GPU (128K or below)
   c. Q6, 1 slot, 160K, projector on GPU
   d. UD-Q5_K_XL (20.9 GB, needs a download; 107 GB free on D:), 2 and 3 slots, projector on GPU, largest window that fits
   Each: VRAM, short and ~94K generation, prompt processing, image encode time, MTP acceptance.
5. Image tokens: default vs --image-min-tokens 1024 vs a lower --image-max-tokens, on the small-text page: answers right or wrong, and prompt time.
6. doc-004 section with the tables and a recommended 32 GB entry; the user chooses. Quality of Q5 vs Q6 is left to the bake-off (TASK-045).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Projector downloaded: unsloth mmproj-F16.gguf as D:\local-ai\models\Qwen3.8-27B-mmproj-F16.gguf, 927,607,488 bytes, SHA-256 cbb841a9ee0636b2ec172f5bb8df2ea8dfeb01e90fe7c6126581d662a0b4e43e (matches HF). Trial entry local-coder-vision in config/llama-swap.yaml and config/litellm.yaml (port 10002). MTP with the projector loaded on b11719: works. Text request draft 621 / accepted 391 at 122.7 tok/s; image request (1280x800 screenshot, 1,036 prompt tokens, 706 ms prompt) draft 93 / accepted 75 at 143.7 tok/s. VRAM with today's flags (Q6, 2 slots, 160K) plus the projector on GPU: 31,710 of 32,607 MiB, 0.9 GB left for the desktop.

Vision checks: 13 questions (IT/EN) on a supplier page screenshot, a scan-like invoice and a 10 px terms page, through llama-swap and the router: 12/13 at the default image size; the 10 px discount code was the miss, fixed by --image-min-tokens 2048 (3/3, ~2,140 tokens, 1.3 s per screenshot, no VRAM cost). Click positions come back in image pixels. Bench (D:\local-ai\scratch\vision): projector on CPU saves 1.3 GB but a screenshot takes 14.4 s and a scan 40 s, so it is out; Q6 2 slots 160K with the projector on GPU leaves 0.8 GB; Q6 2 slots 128K 30,292 MiB (2.3 GB free, 84.8 tok/s at 129K); Q6 1 slot 160K 1.4 GB free; Q5_K_XL 2 slots 160K 1.5 GB free, 3 slots 160K 1.2 GB free, 3 slots 192K spills (pp 759 tok/s at 194K). Q5 read everything right with min 2048. Recorded in doc-004 'Vision projector on the 32 GB card'; recommendation A (Q6, 2 slots, 128K, projector on GPU, min 2048) for the user to choose. Trial entry local-coder-vision still has today's 160K flags; it gets the chosen flags with the user's choice.

User chose option A (Q6, 2 slots, 128K, projector on GPU, --image-min-tokens 2048). Trial entry local-coder-vision set to those flags (-c 131072 hardcoded, the ctx macro stays 160K for local-coder); config parses (Import-PowerShellDataFile, PyYAML), the setup itself was measured in the bench. Projector pinned in scripts/versions.psd1 as model local-coder-vision; Q5_K_XL not pinned, kept on disk for fallback B.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Qwen3.8 27B reads screenshots and scanned pages well enough to be the agents' shared model on the 32 GB card. MTP stays on with the vision projector (b11719). 12/13 vision checks right at the default image size; --image-min-tokens 2048 fixes the 10 px miss at about 1.3 s per screenshot and no VRAM cost. The projector on the CPU is unusable (14 s per screenshot), and today's 160K with 2 slots plus the projector leaves only 0.8 GB. The user chose option A: Q6, 2 slots, 128K, projector on GPU, min 2048 image tokens (30.3 GB, 2.3 GB free, 84.8 tok/s at a full prompt). Recorded in doc-004; trial entry local-coder-vision carries A's flags, the projector is pinned in versions.psd1, local-coder is unchanged. Follow-up: when the entry becomes local-coder (TASK-045 or the m-5 integration), Claude Code's and OpenCode's context limits go to 131,072. Q5 vs Q6 quality is left to the bake-off.
<!-- SECTION:FINAL_SUMMARY:END -->
