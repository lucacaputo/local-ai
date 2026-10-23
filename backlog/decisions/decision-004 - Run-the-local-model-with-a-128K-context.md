---
id: decision-004
title: Run the local model with a 128K context
date: '2026-10-18 15:50'
status: >-
  accepted; partly superseded by TASK-020 (local-coder-q6 at 160K) and
  superseded by decision-009 (one model at 160K, TASK-036)
---
## Context

The PRD assumed a 64K local context (O4). TASK-004 measured Claude Code against it: a request carries about 19K tokens of base prompt and Claude Code reserves a fixed 33K for compaction, so a 64K window compacts at about 36K and leaves roughly 13K of working room. A session reading 7 real source files compacted three times and stopped with "Autocompact is thrashing". Qwen3.6 27B supports 262K natively, and the GPU had about 11 GB of VRAM free at 64K.

## Decision

Run llama-server with `-c 131072` (128K) and tell Claude Code the same window with `CLAUDE_CODE_MAX_CONTEXT_TOKENS=131072` (set in `config/claude-settings.json`). Claude models keep their own 1M window.

## Consequences

- Measured at 128K: 23.6 GB VRAM in total (KV cache 4.35 GiB), 56.5 tok/s generation and 2,345 tok/s prompt processing at a 94.5K-token prompt, so N1 (about 40 tok/s) still holds.
- Compaction fires at about 99.6K estimated tokens (131072 minus the 33K reserve); with reads one per turn the server peaked at 94.7K without overflow.
- Several parallel tool results in one turn (for example many Reads) can add more than 100K tokens at once and overflow the server before compaction can run; a lower assumed window than the server context would add margin.
- The two values must be changed together: `-c` in the llama-server/llama-swap config (TASK-005) and `CLAUDE_CODE_MAX_CONTEXT_TOKENS`.
- About 9 GB of VRAM stays free for the desktop; revisit if games or other GPU users are active while the model is loaded.
