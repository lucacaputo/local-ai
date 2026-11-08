---
id: TASK-039
title: 'Spike: Qwen3.8 27B with the vision projector on the 32 GB card'
status: To Do
assignee: []
created_date: '2026-11-08 17:43'
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
- [ ] #1 The projector for the installed Qwen3.8 file is downloaded with a verified hash and served by llama-swap in a trial entry; the current local-coder entry is unchanged
- [ ] #2 A web page screenshot and a scanned document page sent through the router get correct answers (text read, layout described, a button located), in Italian and in English
- [ ] #3 VRAM, generation speed and prompt processing with an image are measured for at least 2 slots at a shorter window, 1 slot at 160K, and a smaller quant with 2-3 slots, with MTP on and about 1.5 GB kept for the desktop
- [ ] #4 The effect of the image-token setting on reading small text and on prompt time is measured
- [ ] #5 Results and a recommended 32 GB entry are recorded in doc-004 for the user to choose
<!-- AC:END -->
