---
id: decision-002
title: 'Pin llama.cpp, llama-swap, LiteLLM and uv versions'
date: '2026-10-18 14:20'
status: accepted
---
## Context

Spikes and scripts must target the same upstream versions (PRD R7, O10). Versions checked on 2026-10-18. GitHub's "latest" llama.cpp release is a binary-less `v0.7.0`; real builds are tagged `bNNNNN`. No Windows CUDA 12.8 build exists, only 12.4 and 13.4. The driver (617.42) reports CUDA 13.4.

## Decision

Pin these versions:
- llama.cpp `b11719`, `llama-b11719-bin-win-cuda-13.4-x64.zip` plus the matching `cudart-llama-bin-win-cuda-13.4-x64.zip`
- llama-swap `v265`
- LiteLLM `v1.106.0` (the PRD needs at least v1.81.14 for OAuth forwarding)
- uv `0.13.1`
- Tailscale `1.104.1` (winget `Tailscale.Tailscale`)
- Claude Code at least `2.1.257` (2.1.302 installed)

## Consequences

- `scripts/versions.psd1` is the single source of truth for every pin (with SHA-256 hashes); `scripts/install.ps1` installs exactly these versions, including uv and Tailscale through winget, so setups are reproducible. `config/llama-swap.yaml` still names the `llama.cpp-b11719` folder and must be updated together with the llama.cpp pin.
- The CUDA 13.4 build matches the driver; the 12.4 build would need JIT compilation for Blackwell (sm_120).
- Re-confirm the pins after the spikes pass (TASK-002, TASK-003) and record the final set; bump deliberately, not by tracking "latest".
