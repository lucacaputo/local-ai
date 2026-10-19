---
id: TASK-018
title: 'README with usage, troubleshooting and security notes'
status: Done
assignee:
  - '@claude'
created_date: '2026-10-18 22:01'
updated_date: '2026-10-19 11:47'
labels: []
milestone: m-2
dependencies: []
priority: high
ordinal: 18000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The repo has no README. PRD deliverable 7 asks for usage, troubleshooting and security notes, and O10 asks for the pinned versions to be recorded there. Someone returning to this in six months, or the user on a fresh PC, needs one entry point.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 README covers what the stack is, install.ps1, ai-up and ai-down, claude-local on the PC, the Mac client (link to docs), and where models, binaries and logs live
- [x] #2 Troubleshooting covers the known failures: the 128K context split (-kvu), the WSL-launch hang, game guard refusal, 401 and 000 from the router, and Tailscale unreachable
- [x] #3 Security notes state what is bound where, how secrets are stored, the single shared key, the ACL, and what was not tested (public scan)
- [x] #4 The pinned versions in the README match scripts/versions.psd1
- [x] #5 The empty bench/ placeholder is removed or explained, since the bake-off was skipped
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Gather facts from scripts, configs, decisions 001-007 and doc-002 (done): paths, ports, log files, key handling, pins.
2. Write README.md at the repo root: what the stack is, install, daily use (ai-up/ai-down/claude-local), Mac client (link to docs/remote-client-macos.md), where things live, troubleshooting, security notes, pinned versions copied from scripts/versions.psd1.
3. Remove the empty bench/ placeholder (bake-off skipped, doc-002) and its .gitignore line; explain in the README.
4. Check: versions in README vs versions.psd1 by script, every path/script/flag named in the README exists, no secret in the file.
5. Open item: the 'WSL-launch hang' in AC #2 is not recorded anywhere in the repo; ask the user what it was before writing that entry.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
README.md written (what it is, requirements, install, daily use, where things live, pinned versions, troubleshooting table, security notes). bench/.gitkeep removed with its .gitignore entry (bake-off skipped); README says so. Checked by script: every version/folder name in the README appears in scripts/versions.psd1, every script/config/doc path it names exists, no key or IP address in the file. NOT DONE: the 'WSL-launch hang' entry (AC #2) - it is not recorded in the repo, tasks, decisions or doc-002, so I did not invent it; waiting for the user to say what it was. Nothing committed; AC not yet checked.

Follow-up (user): no launch hang was ever seen, so the 'WSL-launch hang' item is dropped from the troubleshooting list. Instead README has a 'From WSL' note: launch scripts with powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/<name>.ps1. Verified only with install.ps1 -CheckOnly from WSL (exit 0, 3 s); ai-up/ai-down not run from WSL.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added README.md at the repo root as the single entry point: what the stack is, requirements, install (install.ps1, init-secrets.ps1), daily use (ai-up, claude-local, ai-down, a 'From WSL' note using powershell.exe), where binaries, model, logs, run state and the key live, pinned versions, a troubleshooting table and security notes. Troubleshooting covers the 128K split (-kvu), game guard refusal, partly-running stack, 401, 000 and Tailscale unreachable, context overflow from parallel Reads, and slow first request. The 'WSL-launch hang' named in AC #2 was never observed by the user, so it was dropped and replaced by the WSL launch note. Security notes state the loopback bindings and tailscale serve, Credential Manager storage, the single shared key and its rotation, the ACL, and what was not tested (public scan, full port scan, a device outside the tailnet, key rotation). The empty bench/ placeholder and its .gitignore line were removed because the bake-off was skipped; the README says so. Verification: every version and folder name in the README matches scripts/versions.psd1, every script/config/doc path it names exists, it contains no key or IP address, and the user reviewed and accepted the text. install.ps1 -CheckOnly was run from WSL via powershell.exe (exit 0). Risks: troubleshooting fixes were taken from earlier task notes and decisions, not rerun; ai-up and ai-down were not run from WSL (the README says so); key rotation is still untested (TASK-017) and the README says that. Not committed.
<!-- SECTION:FINAL_SUMMARY:END -->
