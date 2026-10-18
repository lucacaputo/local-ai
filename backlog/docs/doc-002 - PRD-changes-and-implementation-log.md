---
id: doc-002
title: PRD changes and implementation log
type: other
created_date: '2026-10-18 17:08'
updated_date: '2026-10-18 17:16'
---
# PRD changes and implementation log

The PRD (doc-0001) stays as written on 2026-10-18. This log records where the implementation deviates from it or settles a question it left open, and where the evidence lives. Update it whenever a decision changes.

## Deviations from the PRD

| PRD | What changed | Why | Recorded in |
|---|---|---|---|
| Local context 64K (section 6, O4) | 128K: llama-server `-c 131072`, Claude Code told `CLAUDE_CODE_MAX_CONTEXT_TOKENS=131072` | At 64K Claude Code compacts at ~36K tokens and thrashed; 128K measured at 56 tok/s with a 94K prompt, 23.6 GB VRAM | decision-004, TASK-004 |
| LiteLLM binds the Tailscale address and loopback (R5, section 4) | LiteLLM, llama-swap and llama-server bind to 127.0.0.1 only; `tailscale serve` publishes port 4000 on the tailnet | uvicorn takes one bind address; this leaves nothing on the LAN by construction | decision-006, TASK-007 |
| Windows Firewall rule scoped to the Tailscale interface (R5) | No extra rule: the Tailscale installer's `Tailscale-In` rules already limit inbound to the Tailscale addresses | Nothing else listens on a non-loopback address | decision-006, TASK-007 |
| Router master key and a separate client local key (F6, R1) | One key serves as master and client key | Separate client keys need LiteLLM virtual keys, which need a database | decision-005, TASK-006 |
| 1Password CLI or Windows Credential Manager (O7) | Windows Credential Manager (target `local-ai/router-key`) | 1Password not installed; built into Windows | decision-001, TASK-001, TASK-006 |
| llama.cpp "CUDA 12.8+ build" (R6) | Official `win-cuda-13.4-x64` build plus cudart | No 12.8 build exists; 13.4 matches the driver | decision-002 |
| Models and binaries location (not specified) | `D:\local-ai` (SN850X), outside the repo, `LOCAL_AI_ROOT` | Keeps weights out of git, free space on D: | decision-003 |
| `install.ps1` "checks drivers/CUDA ... verifies Tailscale" (section 8) | Also installs missing uv and Tailscale with winget at pinned versions and downloads the hash-verified model; never installs the NVIDIA driver | Repeatable setup from a bare machine | TASK-008, `scripts/versions.psd1` |
| `ai-up`/`ai-down` optional niceties (O8, section 8) | Game guard built (game-library process paths or less than 22000 MiB VRAM free, `-Force` overrides); no GPU power limit in the scripts (manual `nvidia-smi -pl`, needs admin) | Measured 507-541 W under load; limit needs elevation and is optional | decision-007, TASK-009 |
| llama-swap defaults (section 5) | Idle `ttl` 300 s, `--parallel 2`, `local-light` as an alias; always started with `-listen 127.0.0.1:8080` | Measured unload (306 s), parallel-slot comparison; llama-swap listens on all interfaces by default | TASK-005 |
| LiteLLM to local server over `/v1/messages` (R3, F3) | LiteLLM's `openai/` provider, which calls llama-swap's `/v1/responses` | The `anthropic/` provider type would forward the client OAuth token to the local server | TASK-003 |

## Spike and open-point status

| Item | Status |
|---|---|
| S1 (OAuth through the mixed router) | Pass: token forwarded to Anthropic only; local server gets `Bearer none` (TASK-003) |
| S2 (`/model` list, window, compaction) | Pass with 128K (TASK-004); `modelPicker` rows, discovery not needed |
| S3 (Blackwell, N1) | Pass: 65/65 layers on GPU, 63-77 tok/s (TASK-002) |
| S4 (multi-step tool use) | Pass directly and via the router; tool-call error rate not yet within the R4 gate, see below (TASK-002, TASK-003) |
| O4 context size | Resolved: 128K |
| O5 picker mechanism | Resolved: `modelPicker` + `CLAUDE_CODE_MAX_CONTEXT_TOKENS` |
| O6 LiteLLM mixed config | Resolved: wildcard `anthropic/*` + local models works |
| O7 secret store | Resolved: Credential Manager |
| O8 game guard, power limit | Resolved: guard yes, power limit no (decision-007) |
| O10 pins | Recorded in `scripts/versions.psd1`; re-confirm at the end of the MVP |

## Carried forward to later milestones

- Bake-off: define a hard tool-call failure (malformed call, loop, giving up; gated at 5%) versus a recovered soft error (reported only). The model invents wrong absolute paths (4/18 and 7/7 first Reads in the spikes); measure it.
- Remote milestone: repeat the reachability check from a second tailnet device; tighten the Tailscale ACL; give each device the router key.
- Hardening: a missing router key returns HTTP 500 instead of 401 (LiteLLM without a database); parallel tool results can overflow the 128K window before compaction runs.
