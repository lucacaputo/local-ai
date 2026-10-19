---
id: TASK-032
title: Control service restart schedule survives a reinstall
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 22:22'
updated_date: '2026-10-19 22:36'
labels: []
milestone: m-3
dependencies: []
references:
  - scripts/install-control.ps1
documentation:
  - backlog/docs/doc-002 - PRD-changes-and-implementation-log.md
priority: high
ordinal: 32000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Found while preparing TASK-029. scripts/install-control.ps1 (TASK-026) puts the 10-minute repetition on the at-logon trigger of the scheduled task local-ai-control. A logon trigger's repetition starts only at a logon, and every run of install-control.ps1 registers the task again, so after an install nothing is scheduled until the next logon (NextRunTime empty; observed after the reinstall at about 23:55 on 2026-10-19: no runs at 23:56, 00:06, 00:16). A control service that crashes in that window stays down until someone logs on at the PC, which defeats remote use. The TASK-026 test missed it because it logged off and on after installing.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 After install-control.ps1, the task has a next run time within 10 minutes without a logon
- [x] #2 A killed control service is back within 10 minutes without a logon in between
- [x] #3 The service still starts at logon, install twice and uninstall twice stay safe, and the stack is never started
- [x] #4 doc-002 records the cause and the fix
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. install-control.ps1: two triggers. At logon of the user (starts the service at once after a logon, no repetition), and once at install time repeated every 10 minutes indefinitely (a time trigger keeps its schedule across reinstalls, logons and reboots; runs happen while the user is logged on). Messages and header comment updated.
2. Tests: install, NextRunTime set within 10 minutes; install again, still set; task XML shows both triggers; kill the service and wait for the next run without a logon; uninstall twice, install again; the stack stays down throughout.
3. doc-002: cause and fix in the TASK-026 section's context (new short section for TASK-032).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Fix: install-control.ps1 registers two triggers, at logon (no repetition) and a time trigger from the install time repeated every 10 minutes indefinitely; the install message shows the next check. Tests: install twice, next check 00:33 then 00:34 (10 minutes after each install, no logon); triggers: MSFT_TaskLogonTrigger for CAPS\caput, MSFT_TaskTimeTrigger PT10M indefinite; service killed at 00:24:19, the time trigger ran at 00:34:04 and the service was back at 00:34:05 with 1 allowed login, next check 00:44:03; uninstall twice (second: nothing to remove), install again: next check 10 minutes out, install.ps1 -CheckOnly: installed, running, /control published; the stack stayed down. Not executed yet: a logon with the new triggers (the logon trigger is built as in TASK-026, which passed two logoff/logon tests). doc-002: TASK-032 section, pointers in the TASK-026 section.

AC #3 accepted by the user on the trigger definition: the logon trigger is unchanged from TASK-026, which passed two logoff/logon tests; install and uninstall twice and the stack staying down were tested here.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
The 10-minute restart of the control service hung off the at-logon trigger, whose repetition starts only at a logon, and install-control.ps1 re-registers the task on every run, so after an install nothing restarted a crashed service until the next logon. install-control.ps1 now registers a logon trigger (start at logon) and a separate time trigger from the install time, every 10 minutes indefinitely, and prints the next check. Verified: next check 10 minutes after each of two installs with no logon; a killed service restarted by the time trigger with no logon; uninstall twice and reinstall safe; the stack stayed down. The logon path was accepted on the unchanged trigger definition (tested twice in TASK-026). Recorded in doc-002.
<!-- SECTION:FINAL_SUMMARY:END -->
