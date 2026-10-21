---
id: TASK-036
title: Integrate the chosen local model and flags
status: To Do
assignee: []
created_date: '2026-10-21 20:45'
labels: []
milestone: m-4
dependencies:
  - TASK-033
  - TASK-034
documentation:
  - backlog/docs/doc-002 - PRD-changes-and-implementation-log.md
priority: medium
type: task
ordinal: 36000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-033 and TASK-034 decide the model file, MTP flags, slot count and window; this makes them the installed default on the PC and the Mac. The model list in scripts/versions.psd1 feeds install.ps1, the windows in config/claude-settings.json must match the server context (decision-004, TASK-020), and ai-up refuses or warns from VRAM thresholds sized for the current entries (TASK-020).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 versions.psd1, config/llama-swap.yaml, config/claude-settings.json and the ai-up VRAM thresholds match the chosen model, flags and window, and install.ps1 -CheckOnly reports the model installed
- [ ] #2 Models that were replaced are removed from the model list and the config only if the user agreed in TASK-034
- [ ] #3 The ts-demo task passes through the router from the PC and from the Mac, with Claude models still answering
- [ ] #4 A decision record, doc-002 and the README describe the new setup
<!-- AC:END -->
