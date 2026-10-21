---
id: TASK-034
title: 'Quality check: Qwen3.8 vs Qwen3.6 on our own task set'
status: To Do
assignee: []
created_date: '2026-10-21 20:45'
labels: []
milestone: m-4
dependencies:
  - TASK-033
references:
  - 'https://huggingface.co/unsloth/Qwen3.8-27B-GGUF/discussions/135'
  - 'https://github.com/ggml-org/llama.cpp/issues/27615'
documentation:
  - backlog/docs/doc-002 - PRD-changes-and-implementation-log.md
  - backlog/docs/doc-0001-PRD.md
priority: high
type: task
ordinal: 34000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Qwen3.8-27B reports large agentic gains over Qwen3.6-27B (Terminal-Bench 2.1 73.0 vs 63.4, SWE-bench Pro 61.7 vs 53.5), but these are vendor numbers with no independent replication found. Two community reports matter for us: unsloth dynamic quants looping or not closing on long deep-thinking tasks (unsloth discussion #135, unconfirmed), and generation slowing on long outputs when Claude Code sends many tools (llama.cpp #27615, fix scoped to another chat format). The PRD bake-off (section 6, R4 gate) was skipped in m-1; this is a small version of it. User decision 2026-10-21: Qwen3.8 replaces Qwen3.6 only if it passes this check.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A fixed task set of at least 6 tasks is written down so it can be re-run: the ts-demo edit, a longer multi-step edit, a code review of a real diff, a PR description, a long thinking task and a long output with the full Claude Code tool list
- [ ] #2 Both models run the set in Claude Code through the router with the same settings; pass or fail per task, tool-call failures and tok/s are recorded
- [ ] #3 The long-thinking loop and the many-tools slowdown are each confirmed or ruled out on Qwen3.8
- [ ] #4 Results and a recommendation are in doc-002, and the user decides whether Qwen3.8 replaces Qwen3.6
<!-- AC:END -->
