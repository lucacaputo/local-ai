---
id: doc-002
title: PRD changes and implementation log
type: other
created_date: '2026-10-18 17:08'
updated_date: '2026-10-19 11:59'
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
| Context overflow from parallel tool results (hardening carry-over) | `config/claude-settings.json` env adds `CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS=8000` (cap per Read) and `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=70` (compact earlier). Both PC and Mac use this file | Reproduced with 8 and 16 parallel Reads of ~80 KB files in `claude -p`: with no settings, 8 reads end the turn with `Prompt is too long, automatic compaction failed: summarization produced empty response` (compaction has to send the same oversized conversation); cap only: 8 reads pass, 16 reads end with the 400 `ContextWindowExceededError`; cap plus 70%: 16 reads pass (also with the values coming only from the settings file). Trade-off: files over ~8K tokens are returned truncated and need offset/limit reads, and compaction now starts at about 92K tokens, which in an interactive session (about 67K of system prompt) leaves little room before it; 70 is the only value tested | TASK-015 |
| `ai-up`/`ai-down` failure handling (hardening carry-over) | `ai-up` starts llama-swap and the router through `Start-Detached` (`scripts/lib/stack.ps1`: `cmd.exe /c "exe args >out 2>err"`) instead of `Start-Process -RedirectStandardOutput/-Error`; `ai-down` ignores an unreadable `run\stack.json` (warning) instead of aborting | With `Start-Process` redirects the child inherits the caller's output pipe, so `powershell.exe scripts/ai-up.ps1` run from WSL (or any caller that waits for the pipe to close) did not return until the stack was stopped. A corrupt `stack.json` made `ai-down` fail before stopping anything and kept failing | TASK-016 |
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
- Remote (done in m-1): second tailnet device reachability and the ACL are recorded in the m-1 section below; LAN exposure (A4) is recorded in the TASK-014 section.

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

## LAN exposure check, A4 (TASK-014)

| Check | Result |
|---|---|
| Stack state | `ai-up` running, model loaded (llama-server listening) |
| PC listeners of the stack (from the PC) | llama-server 127.0.0.1:10001; llama-swap 127.0.0.1:8080; router 127.0.0.1:4000 and the tailnet address 100.111.199.22:4000 (`tailscale serve`). Nothing on the Wi-Fi address 192.168.1.101 |
| LAN scan from the Mac, Tailscale off (confirmed: tailnet address gave 000) | `nmap -Pn -p 4000,8080,10001-10010 192.168.1.101` (nmap 7.992): all 12 ports `filtered` (Windows Firewall drops the probes; the services are also loopback-bound) |
| Full TCP scan (`-p-`) | Not completed: too slow against a firewall that drops probes; stopped by the user. Other open Windows ports were therefore not enumerated |
| Public-address scan | Skipped by the user's decision. Exposure would need a router port-forward or UPnP mapping, and the services only bind to loopback; the PC also has a NordVPN interface that would mask the public address |

The PC has a NordVPN interface (`NordLynx`, 10.5.0.2); nothing from the stack listens on it either.

## ai-up and ai-down failure modes (TASK-016)

Run from WSL with `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/<name>.ps1`, model loaded (`ai-up -Warm`) unless noted, starting from an idle machine (no stack process, no listener on 4000/8080/10001, no tailnet serve, no `stack.json`, about 1.6 GB VRAM). Harness and snapshots: `D:\local-ai\scratch\fm\`.

| Case | Setup | Result |
|---|---|---|
| A | Router killed (`taskkill /T /F`) | `ai-down`: stopped tailnet publishing and llama-swap; VRAM 23136 -> 1792 MiB in 2.1 s; no process, listener, serve or state file left |
| B | llama-swap killed alone | llama-server exited with it (the model was already unloaded: 1596 MiB), so no orphan from this; `ai-down` stopped the router and the serve, VRAM idle |
| C1/C2/C4 | `stack.json` with dead pids, empty, or without `vramBaselineMiB`, nothing running | "Nothing was running", file removed |
| C3 | `stack.json` containing `not json {{` | **Before:** `ai-down` died on `ConvertFrom-Json` (exit 1) before stopping anything and left the file, so it failed every time. **After the fix:** warning "Ignoring unreadable ...", normal cleanup, file removed |
| C5 | Same garbage file with the stack running and the model loaded | After the fix: router and llama-swap stopped, VRAM 22963 -> 1614 MiB in 2.1 s |
| D | Second `ai-up` while running | "Stack is already running ... Nothing started."; same pids before and after, exit 0 |
| E1 | `ai-up` after the router was killed (llama-swap alive) | Refused: "The stack is only partly running or a port is taken. Run scripts\ai-down.ps1, then start again." (exit 1, nothing changed); `ai-down` then `ai-up` healthy in 13.5 s |
| E2 | Orphaned llama-server (swap and router gone) holding 18848 MiB on 10001, started from the install folder | `ai-up` refused with the same message, nothing started; `ai-down` stopped it, VRAM 18835 -> 1696 MiB in 6.5 s |
| E3 | Everything hard-killed, tailnet serve and `stack.json` left behind, then `ai-up` without `ai-down` | Healthy in 13.5 s; the serve was reused, state rewritten |
| F | Foreign process listening on `0.0.0.0:4000` (passes the loopback pre-check), so the start fails after llama-swap is up | "Start failed: Port 4000 is already in use on 0.0.0.0 (pid ...) - cleaning up." Afterwards: no llama-swap, no state file, no serve, VRAM idle, the foreign listener untouched |

The launch hang, measured. `ai-up` from WSL printed "Stack healthy in 28.6 s" but `powershell.exe` returned only when a 200 s timeout killed it (exit 124). A 20 s `ping` started with `Start-Process -RedirectStandardOutput/-Error ... -WindowStyle Hidden` kept the caller waiting 20 s, also with `-RedirectStandardInput`; started through `cmd.exe /c "ping ... >o 2>e"` the caller returned in 0 s. After the change `ai-up -Warm` from WSL returns in 22 s with exit 0, the stored key still reaches the router (authenticated `/v1/models` and the warm-up chat both pass), logs are still written, and `stack.json` records the real llama-swap pid (the process returned by `Start-Detached` is the `cmd.exe` wrapper).

Not tested: interrupting `ai-up` itself part-way (Ctrl-C); `ai-down` racing a running `ai-up`; a real game process (the guard was exercised with stand-ins in TASK-009); `ai-up` started from a Windows terminal after the change (only the `powershell.exe`-from-WSL path was run, which is the same code). The `ai-down` "Stopped:" line can list one llama-server pid twice (listener stop plus the sweep); cosmetic.
