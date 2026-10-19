---
id: TASK-021
title: Make context overflows on local models recoverable by Claude Code
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 13:27'
updated_date: '2026-10-19 13:51'
labels: []
milestone: m-2
dependencies: []
references:
  - config/litellm.yaml
  - config/custom_auth.py
documentation:
  - backlog/docs/doc-002 - PRD-changes-and-implementation-log.md
priority: medium
ordinal: 21000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
In TASK-020, 16 parallel full Reads (about 128K tokens of tool results arriving in one step) ended the turn on both local entries, at every compaction percentage tried: llama-server answers exceed_context_size_error, LiteLLM turns it into a 400 ContextWindowExceededError, and Claude Code shows it as an API error and stops. No compaction percentage can absorb a burst larger than the headroom, and Claude Code also undercounts tokens for local models (it estimated 113,851 tokens for a request the server counted at about 177K), so its thresholds fire late. Claude Code does have a reactive path (debug log: "autocompact: routing through reactive", meaning it waits for the API to report prompt-too-long), but it did not treat the LiteLLM 400 as prompt-too-long. If the router reported a local context overflow the way the Anthropic API reports one, Claude Code might compact and retry instead of ending the turn. Unknown so far: which status, error type and message Claude Code recognises. Real Anthropic errors from the Claude pass-through already have the right form and must not be touched. The reproduction harness from TASK-020 is outside the repo: D:\local-ai\scratch\q6\ (ovf-all.sh, ovf8-all.sh, cc.ps1, verdict.py).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 What Claude Code treats as a prompt-too-long error (HTTP status, error type, message pattern, any token counts it parses) is established from its code or a test and recorded
- [ ] #2 A context overflow on a local model reaches Claude Code in that form; Claude model requests and their errors pass through unchanged, and a missing or wrong router key still gets 401 (TASK-011)
- [x] #3 The TASK-020 16-parallel-full-Read reproduction on local-coder and local-coder-q6 no longer ends the turn with an API error: Claude Code compacts or trims and the turn completes; if Claude Code cannot recover even from a recognised error, that is shown and recorded and the router change is reverted
- [x] #4 The 8-parallel-full-Read reproduction and the ts-demo task still pass on local-coder
- [x] #5 doc-002 records the cause, the change and the results
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Research (done). Claude Code 2.1.302 treats an error as prompt-too-long when its message contains "prompt is too long" or "input is too long for requested model" (either status); it parses "prompt is too long ... N tokens > M" to size the cut; its embedded gateway protocol says to relay a 400/413 Anthropic envelope with "prompt is too long: ..." because auto-compact keys on it. LiteLLM 1.106.0 /v1/messages ignores the HTTPException a failure hook returns, but reads e.message after the hook on both the non-streaming and the streaming path, then wraps it in an Anthropic invalid_request_error envelope.
2. config/overflow_errors.py: a CustomLogger whose async_post_call_failure_hook rewrites, in place, the message of a local-model (local-*) overflow (llama-server "request (N tokens) exceeds the available context size (M tokens)") to "prompt is too long: N tokens > M maximum"; anything else untouched. Registered in config/litellm.yaml litellm_settings.callbacks.
3. Router-level check: oversized /v1/messages request to local-coder, streaming and not: expect 400 Anthropic envelope with the new message; normal local and Claude requests unchanged; no key still 401.
4. Claude Code: TASK-020 16-parallel-full-Read reproduction on local-coder and local-coder-q6, 8-Read and ts-demo regression on local-coder. If Claude Code still cannot recover, record it and revert.
5. doc-002 and README troubleshooting.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Results (harness D:\local-ai\scratch\ovr\ and \q6\). Claude Code 2.1.302 prompt-too-long detection: message contains "prompt is too long" or "input is too long for requested model" (either status); parses "prompt is too long ... N tokens > M"; its gateway protocol asks to relay the Anthropic 400/413 envelope. Hook config/overflow_errors.py (LiteLLM failure hook, in-place message rewrite for local-* overflows): router answered 400 {"type":"error","error":{"type":"invalid_request_error","message":"prompt is too long: 147047 tokens > 131072 maximum"}} streaming and not; normal 200; no key 401; sonnet answered through the router. Claude Code with it: 16 full Reads on both entries, error recognised, reactive compaction to last resort, gave up (newest turn larger than the window); forced server overflow with history (test settings, local-coder compaction window 160K over the 128K server): recognised, older history summarised, retry 147,748 tokens, ended (newest turn kept verbatim); two 8-Read steps with repo settings: proactive compaction, local model returned an empty summary. Token counts: router count_tokens 5-7% below llama-server on real files; the synthetic big*.ts are ~1.9 chars per Qwen token, which explains the large undercount in TASK-020. Per criterion 3 the hook was reverted (config/litellm.yaml back to a0edf41; copy at D:\local-ai\scratch\ovr\overflow_errors.py.reverted); after the revert the router returns the LiteLLM text again, 8 full Reads (reg8-q4) and ts-demo (tsdemo-q4-reg, npm test 5/5) pass on local-coder. Criterion 2 was met with the hook and is undone by the revert that criterion 3 requires, so it is left unchecked for the user to decide.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Tried to make local context overflows recoverable by reporting them as Anthropic prompt-too-long errors, and reverted it because Claude Code still cannot recover. Claude Code recognises a message containing "prompt is too long" and a LiteLLM failure hook made the router send exactly that envelope (verified streaming and not; Claude requests and 401 unaffected). With it, Claude Code ran reactive compaction, but compaction keeps the newest turn verbatim, so when the overflow is that turn (16 parallel full Reads, or 8 Reads past a 128K server) the retry is just as large and the turn ends. The router cannot fix that, so per criterion 3 the hook was removed; config is back to commit a0edf41 and the 8-Read and ts-demo regressions pass on local-coder. Side finding: on real files the router token count is only 5-7% below Qwen, so the large undercount seen in TASK-020 comes from the synthetic test text. Recorded in doc-002 and the README troubleshooting row. Remaining risk: a single step of tool results larger than the window ends the turn; untried mitigations are a lower Read cap and asking for fewer files per step. Not committed.
<!-- SECTION:FINAL_SUMMARY:END -->
