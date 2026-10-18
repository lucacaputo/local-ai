---
id: doc-002
title: PRD changes and implementation log
type: other
created_date: '2026-10-18 17:08'
updated_date: '2026-10-18 21:45'
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
| llama.cpp "CUDA 12.8+ build" (R6) | Official `win-cuda-13.4-x64` build plus cudart | No 12.8 build exists; 13.4 matches the driver | decision-002 |
| Models and binaries location (not specified) | `D:\local-ai` (SN850X), outside the repo, `LOCAL_AI_ROOT` | Keeps weights out of git, free space on D: | decision-003 |
| `install.ps1` "checks drivers/CUDA ... verifies Tailscale" (section 8) | Also installs missing uv and Tailscale with winget at pinned versions and downloads the hash-verified model; never installs the NVIDIA driver | Repeatable setup from a bare machine | TASK-008, `scripts/versions.psd1` |
| `ai-up`/`ai-down` optional niceties (O8, section 8) | Game guard built (game-library process paths or less than 22000 MiB VRAM free, `-Force` overrides); no GPU power limit in the scripts (manual `nvidia-smi -pl`, needs admin) | Measured 507-541 W under load; limit needs elevation and is optional | decision-007, TASK-009 |
| llama-swap defaults (section 5) | Idle `ttl` 300 s, `--parallel 2 -kvu` (unified KV pool, so one request can use the full 128K; without `-kvu` each slot gets only 64K, found in the TASK-010 acceptance run), `local-light` as an alias; always started with `-listen 127.0.0.1:8080` | Measured unload (306 s), parallel-slot comparison; llama-swap listens on all interfaces by default | TASK-005, TASK-010 |
| Phase 3 bake-off (sections 6, 9; R4 gate; O1-O3) | Skipped. Qwen3.6 27B Q4_K_M stays `local-coder`, `local-light` stays an alias, Claude Code stays the harness (no OpenCode trial) | User decision 2026-10-18: community consensus already favours Qwen, and Claude Code is the harness the user works in; the benchmark would cost time and tokens for no change in choice | m-1 plan |
| Router key failures (hardening carry-over) | `config/custom_auth.py` (LiteLLM `custom_auth`) compares the `x-litellm-api-key` or `Authorization` bearer with the master key in constant time and answers 401 otherwise. Before: no key gave HTTP 500 (the auth error handler imports the `prisma` package, absent without a database) and a wrong key gave 400 ("No connected db") | Both were opaque for remote clients with a misconfigured key. Installing `prisma` fixed only the no-key case; the hook fixes both with no new dependency. Verified: none, wrong, wrong-suffix keys give 401; the right key (either header) gives 200; `/health/liveliness` stays open; `local-coder` and `sonnet` answer through `claude-local` | TASK-011 |
| Tailscale ACL (R5, "Tailscale ACL limits access to the user's own devices") | Admin-console policy: one grant `{"src": ["autogroup:member"], "dst": ["autogroup:self"], "ip": ["tcp:4000"]}`; the default allow-all grant is removed, the default `ssh` check rule (own devices) is kept | Only the user's own devices can reach port 4000 on the PC, and nothing else on the PC over the tailnet. Applied by the user in the admin console (no API token in this setup) | TASK-013 |
| LiteLLM to local server over `/v1/messages` (R3, F3) | LiteLLM's `openai/` provider, which calls llama-swap's `/v1/responses` | The `anthropic/` provider type would forward the client OAuth token to the local server | TASK-003 |

## Spike and open-point status

| Item | Status |
|---|---|
| S1 (OAuth through the mixed router) | Pass: token forwarded to Anthropic only; local server gets `Bearer none` (TASK-003) |
| S2 (`/model` list, window, compaction) | Pass with 128K (TASK-004); `modelPicker` rows, discovery not needed |
| S3 (Blackwell, N1) | Pass: 65/65 layers on GPU, 63-77 tok/s (TASK-002) |
| S4 (multi-step tool use) | Pass directly and via the router; tool-call error rate not yet within the R4 gate, see below (TASK-002, TASK-003) |
| O4 context size | Resolved: 128K |
| O1 alternative harness, O2 final model, O3 `local-light` model | Resolved by not running the bake-off: Claude Code, Qwen3.6 27B, alias. Reopen only if tool-call failures become a daily problem |
| O5 picker mechanism | Resolved: `modelPicker` + `CLAUDE_CODE_MAX_CONTEXT_TOKENS` |
| O6 LiteLLM mixed config | Resolved: wildcard `anthropic/*` + local models works |
| O8 game guard, power limit | Resolved: guard yes, power limit no (decision-007) |
| O10 pins | Resolved: verified on the real stack in the MVP acceptance run (below); source of truth is `scripts/versions.psd1` |

## Carried forward to later milestones

- Bake-off (skipped, see above): the hard vs soft tool-call failure definition and the wrong-path first Reads (4/18 and 7/7 in the spikes) are not measured. Reopen if they become a problem.
- Remote (done in m-1): second tailnet device reachability and the ACL are recorded in the m-1 section below; the LAN scan (A4) is TASK-014.
- Hardening: parallel tool results can overflow the 128K window before compaction runs.

## Pinned versions that passed the MVP acceptance run (TASK-010)

| Component | Version |
|---|---|
| llama.cpp | b11719 (win-cuda-13.4-x64, `llama-server` 0.7.0-dev, commit 5aeac37a3) |
| llama-swap | v265 (d1e743f) |
| LiteLLM | 1.106.0 (Python 3.12, uv 0.13.1) |
| Model | Qwen3.6-27B-Q4_K_M.gguf (unsloth), SHA-256 in `scripts/versions.psd1` |
| Tailscale | 1.104.1 |
| Claude Code | 2.1.302 (client, not pinned by the scripts) |
| NVIDIA driver | 617.42 (RTX 5090, CUDA 13.x runtime bundled) |

## Remote acceptance run from a Mac (TASK-013)

| Check | Result |
|---|---|
| Device | Mac laptop on the same tailnet, Claude Code with the same subscription login, `scripts/mac/claude-local.sh`, router key in the Keychain |
| `/model` | Claude models plus Local Coder and Local Light listed; local-coder and a Claude model both answered |
| Multi-step edit | `ts-demo` edit task (discount field, `count()`, tests, `npm test`) completed with local-coder from the Mac; all tests pass |
| ACL applied | Reachability check after saving the policy still returned 401 (reachable, no key) |
| After `ai-down` | The same request from the Mac fails (curl prints 000); VRAM 23646 -> 2276 MiB |
| Not tested | A device outside the tailnet or owned by another user being denied by the ACL (no such device); LAN exposure is TASK-014 |
