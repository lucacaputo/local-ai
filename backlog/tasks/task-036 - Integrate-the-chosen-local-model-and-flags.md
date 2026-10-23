---
id: TASK-036
title: Integrate the chosen local model and flags
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-21 20:45'
updated_date: '2026-10-23 06:14'
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
- [x] #1 versions.psd1, config/llama-swap.yaml, config/claude-settings.json and the ai-up VRAM thresholds match the chosen model, flags and window, and install.ps1 -CheckOnly reports the model installed
- [x] #2 Models that were replaced are removed from the model list and the config only if the user agreed in TASK-034
- [ ] #3 The ts-demo task passes through the router from the PC and from the Mac, with Claude models still answering
- [x] #4 A decision record, doc-002 and the README describe the new setup
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Effort: rerun t1-t3 and t6 on Qwen3.8 twice at medium and at high (OpenCode, reasoningEffort per run config), compare with the xhigh runs of TASK-035; pick the default.
2. One local entry (user decision): local-coder = Qwen3.8 UD-Q6_K, MTP draft 3, 160K, 2 slots, the patched chat template, and the chosen effort as the server default (--chat-template-kwargs), so Claude Code gets it too; local-light stays its alias. Remove local-coder-q6 and local-coder-38 from llama-swap.yaml, litellm.yaml, claude-settings.json (picker, windows: one 160K window for all, modelSettings not needed), opencode.json (rename only; effort and launchers are TASK-038).
3. versions.psd1: only the Qwen3.8 file, as local-coder. ai-up: needs only that file; refuse below 22,000 MiB free as before (game guard), warn below 30,200 that the model will not fit; port check 10001 only (one model). ai-down and control-service: port 10001 only. Qwen3.6 files stay on disk.
4. Check: install.ps1 -CheckOnly; a request with no effort gets the default, a request with reasoning_effort overrides it; ts-demo through the router from the PC in Claude Code and OpenCode, a Claude model still answers; ai-up / ai-down / control status. The Mac run needs the user.
5. decision record, doc-002 section, README.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
User decision (2026-10-23): one local entry. local-coder becomes Qwen3.8 UD-Q6_K with MTP at 160K, local-light stays its alias; local-coder-q6 and local-coder-38 are removed, and both Qwen3.6 files leave the model list (files stay on disk).

Effort re-run (Qwen3.8, OpenCode, t1-t3 and t6 x2): medium 6/6 on t1/t2/t6 in 16.4 min, 111K output tokens, no cap hit; 'high' 5/6 in 19.5 min (one t6 hit the 32K cap while thinking and opencode run stopped with no file); xhigh (TASK-035) 6/6 in 34.7 min. The template knows only low/medium/xhigh and maps high to xhigh, so the high runs were a second xhigh sample. t3 empty at every effort (control-token stop). t5 2/2 at medium. Chosen: medium.

Default set with llama-swap env LLAMA_ARG_CHAT_TEMPLATE_KWARGS: --chat-template-kwargs '{...}' made llama-server exit (llama-swap on Windows passes the single quotes through). Prompt lengths on /v1/chat/completions and /v1/responses: no effort 13 = medium 13, low 43, xhigh 55, so Claude Code (no effort through the router) gets medium and a request can still override.

Checks on the PC: install.ps1 -CheckOnly all ok; t1 pass in Claude Code (53 s) and OpenCode (24 s) on local-coder; t5 pass in Claude Code; local-light and Sonnet answer through claude-local.ps1; control status over the tailnet shows local-coder after restarting the service; ai-up warning and refusal with raised thresholds, normal start 13.7 s; model load 12.3 s. Idle free VRAM is 30,455 MiB, 255 MiB above the warning line. decision-009 created, decision-004 marked superseded. Mac run pending (user).
<!-- SECTION:NOTES:END -->
