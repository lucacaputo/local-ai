---
id: TASK-041
title: Sandbox image and one OpenClaw container on Docker Desktop
status: To Do
assignee: []
created_date: '2026-11-08 17:43'
labels: []
milestone: m-5
dependencies: []
references:
  - 'https://docs.openclaw.ai/gateway/local-models'
  - 'https://docs.openclaw.ai/gateway/security'
documentation:
  - backlog/docs/doc-004 - Agent-stack-changes-and-decisions.md
priority: high
type: task
ordinal: 41000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
decision-010 and decision-011: each user's OpenClaw runs in its own Linux container with Chromium, a working folder and a shell, from one image the repo builds from pinned versions. The container is the sandbox, so OpenClaw's own tool sandbox stays off and no nested Docker is used. This task builds the image and runs one container for the owner, reached over the tailnet, as the base for the rest of m-5. Several users, sign-in and the portal belong to m-6.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Docker Desktop (WSL2 backend), OpenClaw and Chromium are pinned in scripts/versions.psd1 and the README pin list, and install.ps1 -CheckOnly reports Docker Desktop and the sandbox image
- [ ] #2 The repo builds the sandbox image from pinned inputs: OpenClaw, Chromium, Python and the office file libraries the bake-off needs
- [ ] #3 A script creates and starts the owner's container with a named volume for its home folder; browser logins, files and OpenClaw state survive a container restart, and a reset deletes them
- [ ] #4 OpenClaw uses the router as an OpenAI-compatible provider with image input and the window and output limits of its slot
- [ ] #5 Only the tools the bake-off needs are allowed, and plugins and skills come only from an allowlist in the repo
- [ ] #6 The owner reaches the OpenClaw web interface from the Mac over the tailnet, and no other port of the container is reachable
<!-- AC:END -->
