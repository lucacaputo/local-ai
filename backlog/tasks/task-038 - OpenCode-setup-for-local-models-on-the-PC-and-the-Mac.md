---
id: TASK-038
title: OpenCode setup for local models on the PC and the Mac
status: To Do
assignee: []
created_date: '2026-10-23 05:20'
labels: []
milestone: m-4
dependencies:
  - TASK-035
  - TASK-036
references:
  - 'https://opencode.ai/docs'
documentation:
  - backlog/docs/doc-002 - PRD-changes-and-implementation-log.md
priority: medium
type: task
ordinal: 38000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-035 adopted OpenCode for local models (user, 2026-10-23); Claude Code stays for Claude models. So far OpenCode only ran on the PC in `opencode run --auto` for the benchmark: there is no pin in the version list, no launcher, nothing in the README, and its interactive interface was never used. On the Mac it gets in by Tailscale identity alone (checked from the PC through the tailnet name), so it needs the router URL but no key. OpenCode can send `reasoning_effort` per model, which llama.cpp renders into the Qwen3.8 template; Claude Code cannot through the router, so the effort chosen in TASK-036 has to be set on both sides. doc-002 (TASK-035 section) lists the Mac setup needs.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The OpenCode version is pinned with the other versions (scripts/versions.psd1 and the README pin list), and autoupdate is off
- [ ] #2 config/opencode.json lists the local models the router serves after TASK-036, with context limits matching the server windows and the reasoning effort chosen there
- [ ] #3 A PC launcher and a Mac launcher (counterparts of claude-local.ps1 and claude-local.sh) start OpenCode against the router; the Mac one uses the saved router URL and no key
- [ ] #4 The ts-demo task passes in the interactive OpenCode interface from the PC and from the Mac, with the reasoning shown and permission prompts working
- [ ] #5 The README and doc-002 describe how to use OpenCode for local models and Claude Code for Claude models
<!-- AC:END -->
