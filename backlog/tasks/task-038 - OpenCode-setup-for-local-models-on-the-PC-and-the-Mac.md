---
id: TASK-038
title: OpenCode setup for local models on the PC and the Mac
status: Done
assignee:
  - '@claude'
created_date: '2026-10-23 05:20'
updated_date: '2026-11-08 16:25'
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
- [x] #1 The OpenCode version is pinned with the other versions (scripts/versions.psd1 and the README pin list), and autoupdate is off
- [x] #2 config/opencode.json lists the local models the router serves after TASK-036, with context limits matching the server windows and the reasoning effort chosen there
- [x] #3 A PC launcher and a Mac launcher (counterparts of claude-local.ps1 and claude-local.sh) start OpenCode against the router; the Mac one uses the saved router URL and no key
- [x] #4 The ts-demo task passes in the interactive OpenCode interface from the PC and from the Mac, with the reasoning shown and permission prompts working
- [x] #5 The README and doc-002 describe how to use OpenCode for local models and Claude Code for Claude models
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Pin OpenCode 1.19.3 (npm opencode-ai) in scripts/versions.psd1. install.ps1 installs it with npm when it is missing and warns on another version; a missing Node is a warning. Add it to the README pin list. autoupdate stays off in the config.
2. config/opencode.json: local-coder and local-light, 163840 context and 32000 output each, reasoningEffort medium (TASK-036). Permissions (user, 2026-10-23): shell asks except read-only commands and test runs; web fetch denied; --auto skips the asks; the 8 Claude-only synced skills denied by name (built-in-browser, chrome-browser, computer-use, docs, google-workspace, morning, import-memory, deep-research).
3. Launchers scripts/opencode-local.ps1 (key from Credential Manager, restored afterwards) and scripts/mac/opencode-local.sh (saved router URL, marker key). Both pass all arguments to opencode. setup-client.sh names the new launcher.
4. Check on the PC: resolved config and agent permissions, models listed, t1 in ts-demo through the PC launcher (run --auto), a shell ask without --auto.
5. README, docs/remote-client-macos.md and a doc-002 section.
6. AC #4: the interactive TUI on the PC and the Mac needs the user.

7. (user, 2026-11-08) Allow PowerShell read-only cmdlets and their aliases in the bash rules, with a last rule '*{*': ask against script blocks; check with opencode run without --auto.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented plan steps 1-5 (see doc-002 section 'OpenCode setup for local models (TASK-038, m-4)'). PC checks: install -CheckOnly reports OpenCode 1.19.3; resolved permissions as configured; t1 through opencode-local.ps1 run --auto passed in 32 s (11 tool calls, none failed, reasoning_effort medium sent, webfetch tool gone, only the 5 file skills plus customize-opencode offered, first prompt 8,719 tokens); without --auto npm test ran and node -e was asked (rejected by opencode run). Open: AC #4, the interactive TUI on the PC and the Mac (user).

AC #3: PC launcher verified (t1 through opencode-local.ps1, see above). Mac launcher not run: the user had no Mac at hand and asked to assume it works (2026-11-08); they will debug it later if it fails.

AC #4 on the PC (2026-11-08): interactive TUI through opencode-local.ps1 (no --auto), driven from a tmux session, in a fresh copy of ts-demo. t1 passed in 50.5 s: own tests 9/9, hidden grader 5/5. Reasoning shown (Thought lines); edits and npm test ran without a prompt; a PowerShell Get-ChildItem was asked and approved with Allow once; node -e was asked and Reject stopped the turn without running it. Mac TUI not run: assumed to work on the user's word, to debug later. Stack started for the test with ai-up -Warm and stopped again with ai-down.

PowerShell rules (user, 2026-11-08): allowed Get-ChildItem, Get-Content, Get-Item, Get-Location, Test-Path, Resolve-Path, Select-String, Select-Object, Measure-Object and gci, dir, gc, cat, type, sls; last rule '*{*': ask, because OpenCode checks each part of a pipe on its own and last match wins, but a script block could run any command inside an allowed cmdlet's argument. Checked with opencode-local.ps1 run (no --auto): Get-ChildItem | Select-Object ran without asking; Get-ChildItem | Remove-Item -WhatIf asked for Remove-Item and was rejected; Select-Object with a script block asked through '*{*' and was rejected. README and doc-002 updated.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
OpenCode is set up as the client for the local models; Claude Code stays for Claude models. OpenCode 1.19.3 is pinned in versions.psd1 and the README; install.ps1 installs it with npm or warns on another version; autoupdate is off. config/opencode.json lists Local Coder and Local Light at 160K/32K with reasoningEffort medium, denies web fetch and the eight Claude-only skills, allows edits, and asks for shell commands except read-only ones and test runs, including the PowerShell read-only cmdlets, with a last '*{*' ask rule against script blocks. New launchers: scripts/opencode-local.ps1 (key from Credential Manager, process-only) and scripts/mac/opencode-local.sh (saved router URL, Tailscale identity, no key). Verified on the PC: t1 through the launcher in opencode run --auto (32 s) and in the interactive TUI (50.5 s, own tests 9/9, hidden 5/5, reasoning shown, Allow once and Reject working), and the PowerShell rules with opencode run. Not verified: everything on the Mac; the user asked to assume it works (2026-11-08) and will debug it later. Note: from WSL, opencode run through powershell.exe needs stdin closed (< /dev/null) or it waits forever.
<!-- SECTION:FINAL_SUMMARY:END -->
