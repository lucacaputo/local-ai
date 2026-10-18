---
id: TASK-015
title: Handle parallel tool results overflowing the 128K window
status: Done
assignee:
  - '@claude'
created_date: '2026-10-18 22:01'
updated_date: '2026-10-18 22:25'
labels: []
milestone: m-2
dependencies: []
priority: medium
ordinal: 15000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Carry-over from the MVP run (doc-002): several parallel tool results can push a request past the 128K window before Claude Code compacts, and the server answers with a context-exceeded 400 that ends the turn. A coding session on the local model should degrade (compact or trim) instead of failing.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The failure is reproduced with a controlled set of large parallel tool results and the error is recorded
- [x] #2 A mitigation (Claude Code compaction setting, output limit or router behaviour) is chosen and applied in config, with the reason in doc-002
- [x] #3 The same reproduction no longer ends the turn with a context-exceeded error
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Reproduce with eight and sixteen parallel Reads of ~80 KB files in claude -p, no mitigation.
2. Try the Claude Code settings found in the binary (per-Read cap, compaction threshold) alone and together on the same reproductions.
3. Put the working values in config/claude-settings.json (shared by PC and Mac) and re-run with the values coming only from that file.
4. Record in doc-002.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Test files and helpers are outside the repo: D:\local-ai\scratch\overflow\big1..16.ts, ovf.ps1, ovf2.ps1, ovf16.ps1; transcripts D:\local-ai\logs\ovf*.jsonl. Results (single run each, local-coder, -p mode): no settings, 8 reads: fails ("Prompt is too long, automatic compaction failed: summarization produced empty response"; it first tried invented paths, then read all 8 in parallel at ~48K chars each); cap 8000 only, 8 reads: pass; cap only, 16 reads: fails with the 400 ContextWindowExceededError; cap 8000 + compact at 70%, 16 reads: pass, and pass again with the values supplied only by config/claude-settings.json. Not tested: the interactive session (system prompt ~67K tokens), other threshold values, MAX_TOOL_USE_CONCURRENCY (limits execution, not the size of the results returned in one step).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Parallel Reads no longer end the turn on the local model. Reproduced in claude -p: 8 parallel Reads of large files failed because compaction itself must send the same oversized conversation; a per-Read cap (CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS=8000) fixed 8 reads, but 16 reads still hit the 400 until compaction was also moved earlier (CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=70). Both are in config/claude-settings.json, used by the PC and the Mac, and 16 parallel reads then complete using only that file. Recorded in doc-002. Risks: single runs; files over ~8K tokens come back truncated; compaction starting at ~92K leaves less room in an interactive session with its ~67K system prompt, and I could not test that session, so if compaction feels too frequent raise the percentage. A burst larger than the headroom (more than ~16 big reads) can still overflow.
<!-- SECTION:FINAL_SUMMARY:END -->
