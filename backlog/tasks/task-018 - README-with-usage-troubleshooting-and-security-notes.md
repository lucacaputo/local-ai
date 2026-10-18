---
id: TASK-018
title: 'README with usage, troubleshooting and security notes'
status: To Do
assignee: []
created_date: '2026-10-18 22:01'
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
- [ ] #1 README covers what the stack is, install.ps1, ai-up and ai-down, claude-local on the PC, the Mac client (link to docs), and where models, binaries and logs live
- [ ] #2 Troubleshooting covers the known failures: the 128K context split (-kvu), the WSL-launch hang, game guard refusal, 401 and 000 from the router, and Tailscale unreachable
- [ ] #3 Security notes state what is bound where, how secrets are stored, the single shared key, the ACL, and what was not tested (public scan)
- [ ] #4 The pinned versions in the README match scripts/versions.psd1
- [ ] #5 The empty bench/ placeholder is removed or explained, since the bake-off was skipped
<!-- AC:END -->
