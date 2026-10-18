---
id: decision-007
title: ai-up refuses to start over a game; no GPU power limit by default
date: '2026-10-18 17:15'
status: accepted
---
## Context

PRD O8 left two optional niceties open: a game-detection guard in `ai-up` and a GPU power limit. The GPU is shared with gaming (PRD section 2); the model plus 128K KV cache needs about 21.6 GB of VRAM (decision-004), and the desktop already uses about 2 GB. Measured on the RTX 5090: 507 W average while generating and 541 W (max 579 W) while processing a prompt, against a 575 W board limit; the card accepts 400-600 W. `nvidia-smi` cannot list per-process VRAM under WDDM (the process table shows N/A).

## Decision

1. `scripts/ai-up.ps1` refuses to start when (a) a process runs from a game library path (Steam, Epic, GOG, EA/Origin, Ubisoft, Battle.net folders, including the `D:\steamGames`, `epic_games`, `gog_games`, `origin_games`, `ubi_games`, `BattlenetGames` folders on this PC) or (b) less than 22000 MiB of VRAM is free. Launchers in Program Files do not count. `-Force` overrides the guard; `-MinFreeVramMiB` and `-GamePathPattern` tune it.
2. No GPU power limit is built into the scripts. Setting one needs an elevated terminal and the PRD marks it optional. To cap the card by hand: `nvidia-smi -pl 460` (about 80%) as administrator; undo with `nvidia-smi -pl 575`. The speed cost has not been measured.

## Consequences

- Starting the stack with a game running gets a clear message instead of an out-of-memory failure or a stuttering game.
- The free-VRAM check is the hard requirement; the path check only names the likely cause and can miss games installed elsewhere (extend the pattern in `scripts/lib/stack.ps1`).
- `ai-down.ps1` frees the GPU in a few seconds (23.4 GB -> 2.1 GB in 2.6 s measured), so switching to a game is `ai-down`, then play.
- If heat or noise matter during long sessions, revisit the power limit and measure tok/s at 460 W first.
