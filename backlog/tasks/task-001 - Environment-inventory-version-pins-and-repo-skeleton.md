---
id: TASK-001
title: 'Environment inventory, version pins and repo skeleton'
status: To Do
assignee: []
created_date: '2026-10-18 14:13'
labels: []
milestone: m-0
dependencies: []
documentation:
  - backlog/docs/doc-0001-PRD.md
priority: high
type: task
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Every later MVP task installs or configures something on this Windows 11 PC (RTX 5090, Blackwell). Before building, we need to know what is already there and which versions to pin (PRD R6, R7, O7, O10), so spikes and scripts target the same versions. The repo also needs a basic layout and ignore rules so model weights, the LiteLLM venv, logs and any env files can never be committed (F6).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 NVIDIA driver version and CUDA 12.8+ (sm_120) support are confirmed and recorded
- [ ] #2 Installed Claude Code version is recorded and is at least v2.1.257 (or the upgrade path is noted)
- [ ] #3 Presence and versions of Tailscale, uv and Python are recorded
- [ ] #4 Secret store is chosen between 1Password CLI and Windows Credential Manager based on what is installed, with the reason recorded (O7)
- [ ] #5 Target versions to pin for llama.cpp, llama-swap and LiteLLM are recorded
- [ ] #6 `scripts/`, `config/` and `bench/` folders exist in the repo
- [ ] #7 `.gitignore` excludes model files, the venv, logs and `.env*` files
<!-- AC:END -->
