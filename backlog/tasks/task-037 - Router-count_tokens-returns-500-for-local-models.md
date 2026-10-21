---
id: TASK-037
title: Router count_tokens returns 500 for local models
status: To Do
assignee: []
created_date: '2026-10-21 20:45'
labels: []
milestone: m-4
dependencies: []
documentation:
  - backlog/docs/doc-002 - PRD-changes-and-implementation-log.md
priority: low
type: bug
ordinal: 37000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
In the TASK-029 run the router answered 8 of 49 /v1/messages/count_tokens requests for local models with 500. In the LiteLLM log, its token counter fails on some tool schemas (KeyError: items in token_counter.py _format_type), and the fallback to llama-swap /v1/responses/input_tokens gets 404. Claude Code uses these counts to estimate context, so wrong or missing counts can affect when it compacts.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A request that returns 500 today is reproduced and the cause confirmed
- [ ] #2 count_tokens for local models returns 200 with a count within about 10% of the llama-server tokenizer, or the 500 is shown to be harmless and that is documented
- [ ] #3 count_tokens for Claude models is unaffected
<!-- AC:END -->
