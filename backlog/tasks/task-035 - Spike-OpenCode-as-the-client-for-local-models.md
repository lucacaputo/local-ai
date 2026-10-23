---
id: TASK-035
title: 'Spike: OpenCode as the client for local models'
status: Done
assignee:
  - '@claude'
created_date: '2026-10-21 20:45'
updated_date: '2026-10-23 05:19'
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
- [x] #1 OpenCode, at a pinned version, runs on the PC against the local Qwen3.8 entry; how it connects (router or llama-swap directly) and why is recorded
- [x] #2 Context used at session start is measured for OpenCode and for Claude Code on the same model
- [x] #3 The TASK-034 task set is run in OpenCode; pass or fail, tool-call failures, compaction behaviour and tok/s are compared with the Claude Code results
- [x] #4 A verdict against the PRD O1 bar is recorded in doc-002; if OpenCode is recommended, what the Mac setup would need is listed
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Install OpenCode 1.19.3 on the PC (npm -g, pinned; 1.19.4 came out on the day of the trial), autoupdate off. Candidate client config config/opencode.json: an openai-compatible provider on the router (http://127.0.0.1:4000/v1, the router key as the bearer).
2. Connect through the router, not llama-swap: the router is the only service the Mac can reach (tailnet port 4000), it holds the key auth, and its OpenAI chat route passes reasoning_effort and the reasoning text through, unlike the /v1/messages route Claude Code uses.
3. Measure the first-request prompt size for both clients on local-coder-38 in a ts-demo copy, from llama-swap's captures.
4. Extend bench/quality/run.ps1 and run-all.ps1 with -Client opencode (stdin prompt, --auto with webfetch denied as in the Claude Code runs, no tools for t5, t6c skipped since OpenCode's list is already short).
5. Run t1-t6 twice on local-coder-38 and on local-coder-q6 in OpenCode; grade t3/t4 by the README rubrics; compare with the TASK-034 Claude Code runs.
6. Compaction: run a long task with a reduced window in each client and record whether it compacts and finishes.
7. Verdict against PRD O1 in doc-002, plus what the Mac setup would need.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
OpenCode 1.19.3 installed with npm -g (pinned; autoupdate and sharing off in config/opencode.json). It connects through the router: the router is the only service the Mac reaches, it does the auth, and its chat route passes reasoning_effort and returns the reasoning. Checked from the PC through the tailnet name with only the Tailscale identity (the key replaced by the marker, and by a wrong value): both answered, so OpenCode sends no browser headers.

Start context on local-coder-38: OpenCode 10,954-11,183 tokens (10 tools); Claude Code 21,155-21,313 at the first request, 49-52K from the second, because Claude Code adds the user's claude.ai connectors (58 tools, about 31K tokens; Gmail send among them). With ENABLE_CLAUDEAI_MCP_SERVERS=false a whole t1 run stayed at 21-24K. Not changed in the repo: the user decides.

Quality set t1-t6 x2 per model in OpenCode: Qwen3.6 11/12 in 15.7 min (Claude Code 11/12, 22.9 min), Qwen3.8 10/12 in 38.7 min (Claude Code 11/12, 55.9 min). Tool failures 1/120 and 2/177 against 30/141 and 4/152. Qwen3.8 t3 gave no answer in 4 of 4 OpenCode runs: quoting the chat template it writes <|im_end|>, which ends the generation. run.ps1 now counts OpenCode's invalid tool calls (one result line corrected by hand) and compactions, and takes -ClientConfig and -Tag.

Compaction, t6 with smaller windows: OpenCode 82K, 1 compaction on Qwen3.8 (pass), none needed on Qwen3.6; Claude Code 100K, 1 on Qwen3.8 and 4 on Qwen3.6 (both pass). No empty summaries. One OpenCode run at the repo's 160K also compacted once and passed. reasoning_effort from opencode.json reaches llama.cpp and changes the Qwen3.8 template's system line (low/xhigh; medium adds none).

User decision (2026-10-23): OpenCode for local models, Claude Code for Claude models; the claude.ai connectors stay enabled in Claude Code. Recorded in doc-002.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
OpenCode 1.19.3 tried as the client for local models through the router. On the TASK-034 set it meets the PRD O1 bar on tool failures (Qwen3.6 21% to 0.8%, Qwen3.8 2.6% to 1.1%), not on pass rate (same on Qwen3.6, one task lower on Qwen3.8 from a control-token stop on t3). It is also about 30% faster on the set, starts at 11K tokens instead of 21-52K, compacts with about twice the room, shows the thinking and can set reasoning_effort per model. Decided by the user: OpenCode for local models, Claude Code for Claude models, claude.ai connectors kept in Claude Code. Verdict and Mac setup needs are in doc-002. Added: config/opencode.json, -Client/-ClientConfig/-Tag in bench/quality. Not tested: OpenCode's interactive interface, long real sessions.
<!-- SECTION:FINAL_SUMMARY:END -->
