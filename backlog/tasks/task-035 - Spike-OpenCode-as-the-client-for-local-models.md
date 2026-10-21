---
id: TASK-035
title: 'Spike: OpenCode as the client for local models'
status: To Do
assignee: []
created_date: '2026-10-21 20:45'
labels: []
milestone: m-4
dependencies:
  - TASK-033
  - TASK-034
references:
  - 'https://opencode.ai/docs'
  - 'https://gist.github.com/komikndr/b17955e1a80ce6ede9a3115f16216bc5/'
  - >-
    https://dev.to/ashraf_chowdury09/claude-code-burns-33k-tokens-before-it-even-reads-your-prompt-45p2
documentation:
  - backlog/docs/doc-002 - PRD-changes-and-implementation-log.md
  - backlog/docs/doc-0001-PRD.md
priority: medium
type: spike
ordinal: 35000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Claude Code starts an interactive session on a local model at about 67K tokens of a 160K window (TASK-020), and local compaction has failed before (TASK-015, TASK-021). OpenCode (MIT, npm opencode-ai, 1.19.3 on 2026-10-16) sends a much smaller prompt: one measurement found about 30K characters of system prompt and tools against about 135K for Claude Code. PRD open point O1 deferred an alternative harness and set the bar for adopting one for local models: about 15+ points pass rate or half the tool failures. OpenCode cannot use the Claude subscription (Anthropic blocks subscription logins in third-party tools since January 2026), so Claude Code stays for Claude models whatever the outcome.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 OpenCode, at a pinned version, runs on the PC against the local Qwen3.8 entry; how it connects (router or llama-swap directly) and why is recorded
- [ ] #2 Context used at session start is measured for OpenCode and for Claude Code on the same model
- [ ] #3 The TASK-034 task set is run in OpenCode; pass or fail, tool-call failures, compaction behaviour and tok/s are compared with the Claude Code results
- [ ] #4 A verdict against the PRD O1 bar is recorded in doc-002; if OpenCode is recommended, what the Mac setup would need is listed
<!-- AC:END -->
