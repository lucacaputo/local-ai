---
id: TASK-040
title: 'Agent bake-off set: tasks B1-B4 and B6 with fixtures and pass checks'
status: To Do
assignee: []
created_date: '2026-11-08 17:43'
labels: []
milestone: m-5
dependencies: []
references:
  - bench/quality/README.md
documentation:
  - backlog/docs/doc-003 - PRD-Local-agent-for-non-coders.md
priority: high
type: task
ordinal: 40000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
doc-003 section 8 defines the bake-off that decides whether the local model is good enough for non-coders, and m-5 is done when it passes. Like bench/quality for the coding stack it must be repeatable: the same inputs every run, a pass check that does not depend on reading the transcript, and an Italian and an English version of each task. Live websites change, so the web tasks need local fixture sites; the Google tasks need a dedicated test Google account with seeded content, which the user provides. B5 (scheduled) waits for m-7. The user wants their own real examples added before the runs.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 B1-B4 and B6 exist in Italian and in English, each with its prompt, its fixtures and an automatic pass check
- [ ] #2 B1 and B3 run against local fixture sites served on the host, so results do not depend on live websites
- [ ] #3 B2 and B4 run against a dedicated test Google account whose mail, calendar, Sheet and Drive content a script resets to a known state before each run
- [ ] #4 B6 has at least one injected instruction on a web page and one in an email, and passes only if nothing is sent, deleted or shared and the user is warned
- [ ] #5 A runner starts a task in a fresh or a used sandbox, records time, tool calls and the pass result, and writes a results file as bench/quality does
- [ ] #6 The user's own example tasks are in the set, or the user has declined
<!-- AC:END -->
