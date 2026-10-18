---
id: TASK-008
title: scripts/install.ps1
status: Done
assignee:
  - '@claude'
created_date: '2026-10-18 14:13'
updated_date: '2026-10-18 17:09'
labels: []
milestone: m-0
dependencies:
  - TASK-005
  - TASK-003
documentation:
  - backlog/docs/doc-0001-PRD.md
  - backlog/docs/doc-002 - PRD-changes-and-implementation-log.md
priority: medium
type: task
ordinal: 8000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Setting up the stack by hand is error-prone and must be repeatable at the versions pinned in the inventory task (PRD deliverable 1, O10).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Script checks the NVIDIA driver/CUDA support, failing with a clear message and a fix hint when it is missing or too old, and checks that Tailscale is present
- [x] #2 Script downloads the pinned llama.cpp CUDA build and llama-swap into a git-ignored location
- [x] #3 Script creates the LiteLLM venv with `uv` at the pinned version
- [x] #4 A second run is safe and makes no changes when everything is present
- [x] #5 Script installs a missing uv and Tailscale with winget at the pinned versions (never the NVIDIA driver), skips installs when the GPU check fails, and tells the user to sign in to Tailscale
- [x] #6 Script downloads the pinned model and verifies its SHA-256 and size; all pins live in `scripts/versions.psd1`
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. scripts/versions.psd1: one place for every pin (decision-002): llama.cpp b11719 win-cuda-13.4 zips + SHA-256, llama-swap v265 zip + SHA-256, LiteLLM 1.106.0, uv 0.13.1, Python 3.12, Qwen3.6-27B-Q4_K_M (repo, file, size, SHA-256). Archive hashes are the GitHub-published digests (I cross-checked them against the zips already downloaded).
2. scripts/install.ps1 [-Root D:\local-ai] [-SkipModel] [-CheckOnly]: preflight (nvidia-smi present, compute capability >= 12.0 and CUDA >= 12.8, Tailscale installed, uv found) failing with clear fix-it messages; then idempotent steps: llama.cpp (+cudart), llama-swap, uv-managed Python + LiteLLM venv, model file (size check on rerun, SHA-256 after download). Each step prints present / installed; archives are hash-verified before extraction and removed afterwards. -CheckOnly changes nothing.
3. Test: preflight failures with bogus tool paths; a first run into a fresh scratch root (D:\local-ai-test, -SkipModel) to exercise downloads, extraction and the venv; a second run proved to change nothing by snapshotting the tree (path, size, mtime) before and after; -CheckOnly and a full run against the real root (everything present, model verified by size). Delete only the scratch root I created.
4. Record results; stop for review.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Results (2026-10-18):

Built scripts/versions.psd1 (all pins: llama.cpp b11719 win-cuda-13.4 + cudart, llama-swap v265, LiteLLM 1.106.0, uv 0.13.1, Python 3.12, model file/size/SHA-256; archive hashes equal the GitHub-published digests, cross-checked) and scripts/install.ps1 [-Root] [-SkipModel] [-CheckOnly] [-NvidiaSmi/-Tailscale/-Uv overrides for testing]. Preflight collects all problems and prints a fix for each: NVIDIA driver/nvidia-smi, compute capability >= 12.0, CUDA >= 12.8, Tailscale installed (warns if logged out), uv found (PATH or the winget package folder), free disk. Steps are idempotent and hash-verified: llama.cpp+cudart, llama-swap, uv-managed Python + LiteLLM venv, model (size check on rerun, SHA-256 after download). Archives are removed after extraction.

Tests: (1) -CheckOnly on the real install: all four items [ok], exit 0. (2) Bogus tool paths and root: all four problems listed with fix-it text, exit 1, nothing changed. (3) Fresh scratch root D:\local-ai-test with -SkipModel: llama.cpp, llama-swap and the LiteLLM venv installed in 42 s; llama-server reports build 11719, llama-swap v265. (4) Second run: all [ok], "Nothing to do"; a snapshot of the whole tree (path, size, mtime; 14,591 files) was identical before and after, so no changes. (5) Deleted llama-swap and reran: only that component was reinstalled. (6) Full model download into the scratch root: 18 min, SHA-256 matched the pin (my attempt to seed a partial file failed, so this was a full download, not a resume test; the curl -C - resume path is untested). Scratch root deleted afterwards.

Notes: uv is not on PATH in shells opened before the winget install, so install.ps1 also looks in the winget package folder; config\llama-swap.yaml still hard-codes the folder llama.cpp-b11719, so bumping the llama.cpp pin means updating both. Test helpers live in D:\local-ai (outside the repo).

Follow-up requested by the user (2026-10-18): the script installs missing prerequisites itself. install.ps1 now installs uv 0.13.1 and Tailscale 1.104.1 with winget (pins added to versions.psd1) when they are missing, before the other steps; -CheckOnly only reports them as [missing] (exit 2); the NVIDIA driver is never installed and a failed GPU check skips all installs; a fresh Tailscale install prints the one-time sign-in hint. Tests: healthy -CheckOnly (exit 0); bogus uv/Tailscale paths with -CheckOnly -> both listed as missing, 2 items; driver missing -> only the driver error, no install attempted; Tailscale install with a bogus path where the pinned version is already installed -> winget no-op and a clear "does not exist" message; real test: uninstalled uv with winget, the installer reinstalled uv 0.13.1 and continued, and the next run printed "Nothing to do". Tailscale was not uninstalled (that would drop the tailnet login); its install path ran via the no-op case. Documents updated: decision-002 (Tailscale pin, versions.psd1 as single source of truth) and a new doc-002 "PRD changes and implementation log" that records every deviation from the PRD and the status of spikes S1-S4 and open points O4-O7, O10; the PRD itself (doc-0001) is left as written.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
scripts/install.ps1 sets up the stack from the pinned versions in scripts/versions.psd1 (llama.cpp b11719 CUDA 13.4, llama-swap v265, LiteLLM 1.106.0, uv 0.13.1, Tailscale 1.104.1, Qwen3.6-27B Q4_K_M, all with SHA-256). It checks the NVIDIA driver/CUDA (compute >= 12.0, CUDA >= 12.8), installs a missing uv and Tailscale with winget (never the driver, and not when the GPU check fails), then installs llama.cpp, llama-swap, the uv-managed LiteLLM venv and the hash-verified model under -Root (default D:\local-ai) idempotently; -CheckOnly reports without changing anything. Verified: fresh scratch root (3 components in 42 s, full model download with matching hash in 18 min), a second run that changed nothing (identical 14,591-file snapshot), repair of a deleted component, failure messages for a missing driver, and a real uv uninstall-reinstall by the script. doc-002 (PRD changes and implementation log) and decision-002 were updated.

Risks/follow-ups (not created as tasks): the curl resume path for interrupted model downloads is untested; the Tailscale install path itself was exercised only via the already-installed no-op case (uninstalling would drop the tailnet login); a fresh Tailscale install shows a Windows permission prompt and needs a one-time tailscale login; config/llama-swap.yaml hard-codes the llama.cpp-b11719 folder and must change with the pin.
<!-- SECTION:FINAL_SUMMARY:END -->
