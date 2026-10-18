---
id: TASK-003
title: 'Spike S1/S4: LiteLLM router with Claude pass-through and local-coder'
status: To Do
assignee: []
created_date: '2026-10-18 14:13'
labels: []
milestone: m-0
dependencies:
  - TASK-002
documentation:
  - backlog/docs/doc-0001-PRD.md
priority: high
type: spike
ordinal: 3000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A single endpoint must serve both real Claude models (on the subscription OAuth login, not per-token API billing) and local models, so one Claude Code session can use either (PRD F1, R1, R7). LiteLLM docs do not show this mixed config, so it must be proven by test (O6). Router auth must use `x-litellm-api-key` via `ANTHROPIC_CUSTOM_HEADERS`, and neither `ANTHROPIC_AUTH_TOKEN` nor `ANTHROPIC_API_KEY` may be set. Fallbacks: F1 (separate `claude-local` profile) if the mixed config fails; F3 (OpenAI route to the local server) if the Anthropic route misbehaves with tools.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 LiteLLM runs from a `uv` venv at a pinned version (v1.81.14+), with no database
- [ ] #2 `config/litellm.yaml` defines `anthropic/*` pass-through and `local-coder` pointing at the loopback llama-server
- [ ] #3 Router rejects requests without the local key
- [ ] #4 One Claude Code session on the subscription login calls a Claude model and `local-coder` through the router
- [ ] #5 Evidence shows Claude requests use the subscription, not API billing
- [ ] #6 Local deployment never receives the OAuth token
- [ ] #7 A multi-step tool-use task completes on `local-coder` through the router
- [ ] #8 Outcome is recorded: pass, or which fallback (F1/F3) was taken
<!-- AC:END -->
