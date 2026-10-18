---
id: TASK-001
title: 'Environment inventory, version pins and repo skeleton'
status: Done
assignee:
  - '@claude'
created_date: '2026-10-18 14:13'
updated_date: '2026-10-18 14:23'
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
- [x] #1 NVIDIA driver version and CUDA 12.8+ (sm_120) support are confirmed and recorded
- [x] #2 Installed Claude Code version is recorded and is at least v2.1.257 (or the upgrade path is noted)
- [x] #3 Presence and versions of Tailscale, uv and Python are recorded
- [x] #4 Secret store is chosen between 1Password CLI and Windows Credential Manager based on what is installed, with the reason recorded (O7)
- [x] #5 Target versions to pin for llama.cpp, llama-swap and LiteLLM are recorded
- [x] #6 `scripts/`, `config/` and `bench/` folders exist in the repo
- [x] #7 `.gitignore` excludes model files, the venv, logs and `.env*` files
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Read-only inventory of the Windows host (nvidia-smi, Claude Code, Tailscale, uv, Python, secret stores, disks).
2. Look up latest upstream releases for llama.cpp, llama-swap, LiteLLM and pick pin candidates.
3. Record findings and open decisions in the task notes.
4. Create scripts/, config/, bench/ and extend .gitignore.
5. Stop for review: secret store choice and pins need user sign-off before AC #4 and #5 are checked.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Inventory (2026-10-18, Windows host, read-only):
- GPU: RTX 5090 32607 MiB, driver 617.42, CUDA UMD 13.4 (>= 12.8, sm_120 OK). Desktop already holds ~1.8 GB VRAM idle, so budget ~30 GB for model + KV cache.
- Claude Code 2.1.302 (>= 2.1.257 OK).
- PowerShell 5.1.26100 only (no pwsh 7). winget v1.29 present.
- NOT installed: Tailscale, uv, Python, 1Password CLI/app, Git for Windows (git only in WSL).
- Secret store candidates: Windows Credential Manager (cmdkey built in; PS 5.1 has no SecretManagement module). 1Password absent.
- Disks: D: = WD SN850X (WDS100T1X0E), 158 GB free; E: = Samsung 980 Pro, 224 GB free; C: = SK hynix SHPP41 2 TB, 804 GB free (not in PRD table); Sabrent has no drive letter.

Upstream versions (checked 2026-10-18):
- llama.cpp: tags are bNNNNN; newest b11719 (2026-10-18). GitHub "latest" is a binary-less v0.7.0, so pin a bNNNNN tag. Windows CUDA assets: llama-bNNNNN-bin-win-cuda-12.4-x64.zip and cuda-13.4-x64.zip (+ matching cudart zip). No 12.8 build; PRD said "12.x", so choose 13.4 to match the driver (12.4 PTX would need JIT for sm_120).
- llama-swap: v265 (2026-10-14), llama-swap_265_windows_amd64.zip.
- LiteLLM: v1.106.0 stable (2026-10-18); 1.107 is rc. PRD needs >= v1.81.14 for OAuth forwarding.
- uv: 0.13.1.

Open decisions for user: (a) secret store, (b) pin set, (c) install location for models/binaries.

Decisions (user-approved 2026-10-18):
- Secret store: Windows Credential Manager (built in; 1Password not installed). Injection from PowerShell 5.1 needs a small helper (TASK-006). Closes O7.
- Pins: llama.cpp b11719 (win-cuda-13.4-x64 + matching cudart-llama-bin-win-cuda-13.4-x64 zip), llama-swap v265, LiteLLM v1.106.0, uv 0.13.1; Claude Code >= 2.1.257 (2.1.302 installed). Closes O10 for the pin candidates; re-confirm after the spikes pass.
- Install location: models and binaries on D: (WD SN850X, 158 GB free), git-ignored.

Verification: scripts/, config/, bench/ exist; `git check-ignore` confirms .gitignore matches *.gguf, *.safetensors, models/, .venv/, logs/, *.log, .env, .env.*, bin/, tools/, while the .gitkeep files stay trackable. Decisions recorded as decision-001..003.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Inventoried the Windows host (RTX 5090, driver 617.42 / CUDA 13.4, Claude Code 2.1.302; Tailscale, uv, Python and 1Password not installed), picked and recorded pins (llama.cpp b11719 CUDA 13.4, llama-swap v265, LiteLLM v1.106.0, uv 0.13.1), chose Windows Credential Manager and D: for models, and created scripts/, config/, bench/ plus a .gitignore covering models, binaries, venv, logs and env files. Decisions are in backlog/decisions (001-003).

Verified with git check-ignore and directory listing; inventory values come from commands run on the host.

Follow-ups (not created): Tailscale, uv and Python must be installed before TASK-003/007/008; the pins should be re-confirmed after the spikes; a Credential Manager read helper is needed in TASK-006.
<!-- SECTION:FINAL_SUMMARY:END -->
