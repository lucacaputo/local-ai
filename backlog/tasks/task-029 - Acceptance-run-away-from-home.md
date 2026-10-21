---
id: TASK-029
title: Acceptance run away from home
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 14:32'
updated_date: '2026-10-21 17:23'
labels: []
milestone: m-3
dependencies:
  - TASK-028
documentation:
  - backlog/docs/doc-002 - PRD-changes-and-implementation-log.md
priority: medium
ordinal: 29000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The point of m-3 is that the user can set up and use the stack without being at the PC. This runs the whole flow from the Mac on a different network, as the milestone done-when describes.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 From the Mac on another network (for example a phone hotspot), with the PC on and the user logged in, a fresh client setup without a key succeeds without touching the PC
- [x] #2 ai-remote up starts the stack; in Claude Code /model lists Claude and local models, a local and a Claude model answer, and the ts-demo multi-step edit completes with local-coder
- [x] #3 ai-remote down stops the stack, and status then shows it down with VRAM near idle
- [x] #4 Results are recorded in doc-002, and m-3 is ready for archiving with the user approval
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. PC before the run: stack down, control service running, /control published, sleep and hibernate on AC set to never (checked: both 0), ts-demo package in its reset state.
2. Mac on another network (phone hotspot), run by the user: confirm the network (hotspot address; tailscale ping caps shows direct or DERP). Fresh client setup: remove ~/.config/local-ai/router-url, run setup-client.sh with the URL (no key; the stack is down, so it reports the router not answering).
3. ai-remote.sh status (down), up, status (up); setup-client.sh again accepts the login; claude-local.sh: /model lists Claude and local models; one prompt on local-coder and one on a Claude model; the ts-demo edit (discountPercent with RangeError, Cart.count(), tests, npm test) on local-coder in a reset copy.
4. ai-remote.sh down, then status: down with VRAM near idle.
5. Record results in doc-002; ask the user before archiving m-3.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Run by the user from the Mac away from home on 2026-10-21; they reported every step passed. PC-side evidence from the logs: control service POST /up 200 at 09:53:41 (healthy in 16.8 s) and POST /down 200 at 16:58:41, both by the allowlisted login; 867 router requests from the Mac, 833 answered 200. After the run: VRAM 1,607 MiB, tailscale serve publishes only /control. Router-side errors not visible to the user: 29 x 429 from Anthropic (rate limit) and 8 x 500 on count_tokens for local models (LiteLLM token counter KeyError on tool schemas). Results recorded in doc-002.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
m-3 acceptance run passed. From the Mac on another network the user set up the client with the URL alone (no key, nothing done at the PC), started the stack with ai-remote up, used local and Claude models in Claude Code including the ts-demo multi-step edit on local-coder, and stopped it with ai-remote down. Control and router logs on the PC confirm the up/down calls and the traffic; VRAM was back to idle afterwards. Results are in doc-002. Not covered: a PC that is really asleep (Wake-on-LAN out of scope). Possible follow-up, not created: 500s from LiteLLM count_tokens on local models.
<!-- SECTION:FINAL_SUMMARY:END -->
