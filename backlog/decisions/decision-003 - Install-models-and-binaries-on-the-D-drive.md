---
id: decision-003
title: 'Install models and binaries on the D: drive'
date: '2026-10-18 14:20'
status: accepted
---
## Context

Model weights (Qwen3.6 27B Q4_K_M is about 17 GB) and llama.cpp/llama-swap binaries are large and must stay out of the repo. The PRD puts models on the WD SN850X, which is `D:` (158 GB free). `E:` (Samsung 980 Pro) has 224 GB free; `C:` (2 TB SK hynix, not in the PRD) has 804 GB free.

## Decision

Keep models and binaries on `D:` (SN850X), outside git. The repo `.gitignore` excludes `*.gguf`, `models/`, `bin/` and `tools/`.

## Consequences

- 158 GB of free space holds a handful of models; revisit if the bake-off downloads many challengers (use `E:` or `C:` then).
- `install.ps1` and the configs take the location as a parameter instead of hard-coding it.
