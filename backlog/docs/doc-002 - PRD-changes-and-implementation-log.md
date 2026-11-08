---
id: doc-002
title: PRD changes and implementation log
type: other
created_date: '2026-10-18 17:08'
updated_date: '2026-11-08 16:23'
---
# PRD changes and implementation log

The PRD (doc-0001) stays as written on 2026-10-18. This log records where the implementation deviates from it or settles a question it left open, and where the evidence lives. Update it whenever a decision changes.

## Deviations from the PRD

| PRD | What changed | Why | Recorded in |
|---|---|---|---|
| Local context 64K (section 6, O4) | 128K for `local-coder` and `local-light`: llama-server `-c 131072`, and Claude Code compacts within it through `modelSettings.<model>.autoCompactWindow=131072`. `local-coder-q6` has 160K (`-c 163840`); `CLAUDE_CODE_MAX_CONTEXT_TOKENS=163840`, one value for every local model, matches the largest server (TASK-020) | At 64K Claude Code compacts at ~36K tokens and thrashed; 128K measured at 56 tok/s with a 94K prompt, 23.6 GB VRAM | decision-004, TASK-004, TASK-020 |
| LiteLLM binds the Tailscale address and loopback (R5, section 4) | LiteLLM, llama-swap, llama-server and the control service bind to 127.0.0.1 only; `tailscale serve` publishes port 4000 on the tailnet, in HTTP mode since m-3 with two routes, `/` (router) and `/control` (control service) | uvicorn takes one bind address; this leaves nothing on the LAN by construction | decision-006, decision-008, TASK-007, TASK-023, TASK-026 |
| Windows Firewall rule scoped to the Tailscale interface (R5) | No extra rule: the Tailscale installer's `Tailscale-In` rules already limit inbound to the Tailscale addresses | Nothing else listens on a non-loopback address | decision-006, TASK-007 |
| Router master key and a separate client local key (F6, R1) | One key serves as master and client key. Since m-3 it is used only on the PC; remote devices hold no key (next row) | Separate client keys need LiteLLM virtual keys, which need a database | decision-005, TASK-006 |
| Clients authenticate with a local key (sections 4 and 5) | Remote devices get in by their Tailscale login: `tailscale serve` passes it in `Tailscale-User-Login`, and the router lets in the logins on an allowlist (by default the login the PC is signed in with). Requests from a browser are refused on this path | A key copied to every device had to be set up from the PC, which fails away from home; the tailnet already identifies the user | decision-008, TASK-023, TASK-024, TASK-031 |
| F4: one command to start the stack, one to stop it, no auto-start at boot | A control service starts at logon (scheduled task) and runs `ai-up` or `ai-down` only when asked, from the Mac with `ai-remote.sh`. The AI stack itself still never starts by itself | Starting and stopping the stack away from home | decision-008, TASK-025, TASK-026, TASK-027 |
| llama.cpp "CUDA 12.8+ build" (R6) | Official `win-cuda-13.4-x64` build plus cudart | No 12.8 build exists; 13.4 matches the driver | decision-002 |
| Models and binaries location (not specified) | `D:\local-ai` (SN850X), outside the repo, `LOCAL_AI_ROOT` | Keeps weights out of git, free space on D: | decision-003 |
| `install.ps1` "checks drivers/CUDA ... verifies Tailscale" (section 8) | Also installs missing uv and Tailscale with winget at pinned versions and downloads the hash-verified model; never installs the NVIDIA driver | Repeatable setup from a bare machine | TASK-008, `scripts/versions.psd1` |
| `ai-up`/`ai-down` optional niceties (O8, section 8) | Game guard built (game-library process paths or less than 22000 MiB VRAM free, `-Force` overrides); no GPU power limit in the scripts (manual `nvidia-smi -pl`, needs admin) | Measured 507-541 W under load; limit needs elevation and is optional | decision-007, TASK-009 |
| llama-swap defaults (section 5) | Idle `ttl` 300 s, `--parallel 2 -kvu` (unified KV pool, so one request can use the full 128K; without `-kvu` each slot gets only 64K, found in the TASK-010 acceptance run), `local-light` as an alias; always started with `-listen 127.0.0.1:8080` | Measured unload (306 s), parallel-slot comparison; llama-swap listens on all interfaces by default | TASK-005, TASK-010 |
| Phase 3 bake-off (sections 6, 9; R4 gate; O1-O3) | Skipped. Qwen3.6 27B Q4_K_M stays `local-coder`, `local-light` stays an alias, Claude Code stays the harness (no OpenCode trial) | User decision 2026-10-18: community consensus already favours Qwen, and Claude Code is the harness the user works in; the benchmark would cost time and tokens for no change in choice | m-1 plan |
| Router key failures (hardening carry-over) | `config/custom_auth.py` (LiteLLM `custom_auth`) compares the `x-litellm-api-key` or `Authorization` bearer with the master key in constant time and answers 401 otherwise. Before: no key gave HTTP 500 (the auth error handler imports the `prisma` package, absent without a database) and a wrong key gave 400 ("No connected db") | Both were opaque for remote clients with a misconfigured key. Installing `prisma` fixed only the no-key case; the hook fixes both with no new dependency. Verified: none, wrong, wrong-suffix keys give 401; the right key (either header) gives 200; `/health/liveliness` stays open; `local-coder` and `sonnet` answer through `claude-local` | TASK-011 |
| Tailscale ACL (R5, "Tailscale ACL limits access to the user's own devices") | Admin-console policy: one grant `{"src": ["autogroup:member"], "dst": ["autogroup:self"], "ip": ["tcp:4000"]}`; the default allow-all grant is removed, the default `ssh` check rule (own devices) is kept | Only the user's own devices can reach port 4000 on the PC, and nothing else on the PC over the tailnet. Applied by the user in the admin console (no API token in this setup) | TASK-013 |
| Context overflow from parallel tool results (hardening carry-over) | `config/claude-settings.json` env sets `CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS=8000` (cap per Read) and `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=80` (70 in TASK-015, raised in TASK-020). Both PC and Mac use this file | TASK-015: with no settings, 8 parallel full Reads of ~80 KB files ended the turn with `Prompt is too long, automatic compaction failed: summarization produced empty response`; with the cap, 8 full Reads pass. **Corrected in TASK-020:** the TASK-015 16-Read passes at 70% (`ovf16B`, `ovf16C`) read one line per file (`limit=1`). With full reads, 16 Reads (about 128K tokens of results in one step) end with the 400 `ContextWindowExceededError` on both local entries at 70% and 80%, while 8 full Reads pass at 70, 80 and 90%. The percentage applies to the effective window (window minus 20K) and can only lower Claude Code's default threshold (effective window minus 13K): 70% compacted local-coder at 77,750 tokens, not the ~92K recorded here before; 80% compacts at about 88.9K (local-coder) and 115.1K (local-coder-q6). Files over ~8K tokens come back truncated and need offset/limit reads. A single step of tool results larger than the window still ends the turn; reporting it as prompt-too-long does not help (TASK-021) | TASK-015, TASK-020, TASK-021 |
| `ai-up`/`ai-down` failure handling (hardening carry-over) | `ai-up` starts llama-swap and the router through `Start-Detached` (`scripts/lib/stack.ps1`: `cmd.exe /c "exe args >out 2>err"`) instead of `Start-Process -RedirectStandardOutput/-Error`; `ai-down` ignores an unreadable `run\stack.json` (warning) instead of aborting | With `Start-Process` redirects the child inherits the caller's output pipe, so `powershell.exe scripts/ai-up.ps1` run from WSL (or any caller that waits for the pipe to close) did not return until the stack was stopped. A corrupt `stack.json` made `ai-down` fail before stopping anything and kept failing | TASK-016 |
| Model choice (section 6, O2) | Qwen3.6 27B Q6_K added as `local-coder-q6` (160K window) next to the Q4_K_M `local-coder`, not instead of it | User decision 2026-10-19: try the higher quant without giving up the current one. Measured 15-20% slower generation, 27.7 GB held by llama-server at 160K, no system-memory fallback | TASK-020 |
| LiteLLM to local server over `/v1/messages` (R3, F3) | LiteLLM's `openai/` provider, which calls llama-swap's `/v1/responses` | The `anthropic/` provider type would forward the client OAuth token to the local server | TASK-003 |

## Spike and open-point status

| Item | Status |
|---|---|
| S1 (OAuth through the mixed router) | Pass: token forwarded to Anthropic only; local server gets `Bearer none` (TASK-003) |
| S2 (`/model` list, window, compaction) | Pass with 128K (TASK-004); `modelPicker` rows, discovery not needed |
| S3 (Blackwell, N1) | Pass: 65/65 layers on GPU, 63-77 tok/s (TASK-002) |
| S4 (multi-step tool use) | Pass directly and via the router; tool-call error rate not measured against the R4 gate, see "Open items after m-2" (TASK-002, TASK-003) |
| O4 context size | Resolved: 160K for the one local entry, `local-coder` (decision-009, TASK-036); earlier 128K for the Q4_K_M entries and 160K for `local-coder-q6` (TASK-020) |
| O1 alternative harness | Resolved: OpenCode for local models, Claude Code for Claude models (TASK-035, user 2026-10-23); it met the bar on tool failures, not on pass rate |
| O2 final model, O3 `local-light` model | Resolved by not running the bake-off: Qwen3.6 27B, alias. The Q6_K quant of the same model was added as `local-coder-q6` (TASK-020); replaced by Qwen3.8 UD-Q6_K with MTP as the only local model (decision-009, TASK-036) |
| O5 picker mechanism | Resolved: `modelPicker` + `CLAUDE_CODE_MAX_CONTEXT_TOKENS`, and per-model `modelSettings.<model>.autoCompactWindow` when local models have different windows (TASK-020) |
| O6 LiteLLM mixed config | Resolved: wildcard `anthropic/*` + local models works |
| O7 secret store | Resolved: Windows Credential Manager, since the 1Password CLI was not installed (decision-001); rotation tested on the PC and the Mac (TASK-017) |
| O8 game guard, power limit | Resolved: guard yes, power limit no (decision-007) |
| O9 RAM upgrade to 64 GB+ | Open by design: no upgrade planned (PRD section 2). Reopen model selection (larger MoE models with CPU offload) if it happens |
| O10 pins | Resolved: verified on the real stack in the MVP acceptance run (below); source of truth is `scripts/versions.psd1`, listed in the README (TASK-018) |

## Open items after m-2

- Bake-off (skipped, see above): the hard vs soft tool-call failure definition is not measured. The wrong-path first Read (4/18 and 7/7 in the spikes) still shows up: almost every TASK-020/TASK-021 run first read the files at a wrong path, then retried correctly. Reopen if tool-call failures become a daily problem.
- Context bursts: one step whose tool results exceed the window (for example 16 parallel full Reads at the 8K cap, about 128K tokens) ends the turn on both local entries. Router-side recovery was tried and reverted (TASK-021). Not tried: a lower Read cap, asking for fewer files per step.
- Compaction by the local model sometimes returns an empty summary ("automatic compaction failed: summarization produced empty response"), seen in stress tests in TASK-015 and TASK-021; how often it happens in real sessions is unknown.
- Not tested: a device outside the tailnet or of another user being refused by the ACL, a scan from the public internet and a full `-p-` port scan (TASK-013, TASK-014); interrupting `ai-up` part-way and `ai-down` racing `ai-up` (TASK-016); tool-call reliability of the Q6_K beyond one ts-demo run (TASK-020).
- LiteLLM logs at startup that `custom_auth_run_common_checks` is not set. It only matters for budgets, model allowlists and rate limits stored in a LiteLLM database, which this router does not have (R7, decision-005), so it stays unset.
- Remote (done in m-1): second tailnet device reachability and the ACL are recorded in the m-1 section below; LAN exposure (A4) is recorded in the TASK-014 section.

## Pinned versions that passed the MVP acceptance run (TASK-010)

| Component | Version |
|---|---|
| llama.cpp | b11719 (win-cuda-13.4-x64, `llama-server` 0.7.0-dev, commit 5aeac37a3) |
| llama-swap | v265 (d1e743f) |
| LiteLLM | 1.106.0 (Python 3.12, uv 0.13.1) |
| Model | Qwen3.6-27B-Q4_K_M.gguf (unsloth), SHA-256 in `scripts/versions.psd1` |
| Model, added in TASK-020 | Qwen3.6-27B-Q6_K.gguf (unsloth, 22,523,238,624 bytes), SHA-256 in `scripts/versions.psd1` |
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

## Q6_K entry, windows and compaction (TASK-020)

`local-coder-q6` serves Qwen3.6-27B-Q6_K.gguf through llama-swap and LiteLLM with the same flags as `local-coder` and a 160K window; `local-coder` and `local-light` keep the Q4_K_M at 128K. Measured directly against a bench llama-swap (same flags, every prompt starting with a fresh GUID so the prompt cache cannot help), desktop idle at about 1.55 GB:

| Setup | VRAM in use, model loaded | Generation: short / ~94K prompt / near-full prompt | Prompt processing: ~94K / near-full | Near-full prompt |
|---|---|---|---|---|
| Q4_K_M, 128K | 22,928 MiB (llama-server 21,354) | 76.9 / 56.8 / 51.0 tok/s | 2,385 / 1,976 tok/s | 128,450 tokens, 71 s |
| Q6_K, 128K | 27,964 MiB (26,482) | 61.6 / 47.8 / 44.2 tok/s | 2,184 / 1,831 tok/s | 128,453 tokens, 79 s |
| **Q6_K, 160K (chosen)** | 29,261 MiB (27,730) | 61.9 / 48.1 / 41.0 tok/s | 2,149 / 1,594 tok/s | 160,935 tokens, 108 s |
| Q6_K, 192K | 30,520 MiB (28,980) | 61.8 / 48.1 / 37.9 tok/s | 2,163 / 1,441 tok/s | 193,950 tokens, 142 s |

No system-memory fallback at any window: speed at ~94K is the same for every window, and the GPU shared memory of llama-server only grows by 32 MiB per 32K step (pinned buffers). The user kept the entry, with 160K and 80% compaction (2026-10-19). 160K was chosen over 192K: at 192K about 1.7 GB is left for the desktop and generation at a full prompt drops below 40 tok/s (N1). The Q6_K loads in 18 s (27 s on a cold disk cache).

| Check | Result |
|---|---|
| Install | `install.ps1` downloads and hash-verifies both models from the model list in `scripts/versions.psd1` (Q6_K: 1,021 s); `-CheckOnly` lists both |
| Claude Code windows | Debug log `effectiveWindow`: local-coder 111,072 and local-light 111,072 (128K minus the 20K output reserve), local-coder-q6 143,840 (160K minus 20K). Without the `modelSettings` entry, local-light followed the 160K global window |
| Switching through the router | local-coder -> local-coder-q6 13.1 s, back 11.5-12.1 s, local-light after local-coder 0.3 s (same process). In 185 samples at 0.5 s there was never more than one llama-server and VRAM went back to idle before each load; peak 29,281 MiB |
| Ports | llama-swap gives each model its own llama-server port in config order: 10001 local-coder, 10002 local-coder-q6 (inside the 10001-10010 range scanned in TASK-014, loopback only). `ai-up` pre-check and `ai-down` now cover 10002 (tested with the Q6_K loaded, and with a foreign listener on 10002) |
| Multi-step edit | TASK-013 ts-demo task on local-coder-q6: done in 61 s, 10 tool calls (one wrong-path first Read), correct edits, `npm test` 5/5 |
| Overflow, 8 parallel full Reads | Pass on both entries at 70, 80 and 90%. 80% chosen (user, 2026-10-19): working room after an interactive session start of ~67K grows from ~10K to ~22K (local-coder) and to ~48K (local-coder-q6) |
| Overflow, 16 parallel full Reads | Fail on both entries at 70% and 80% (request about 177K tokens). Claude Code estimated 113,851 tokens before compacting, so it undercounts this synthetic text by about 55%, and the LiteLLM 400 is not taken as prompt-too-long. TASK-021: even when the error is recognised, Claude Code keeps the newest turn, so such a burst still ends the turn |
| ai-up guard | Refuses below 22,000 MiB free as before; warns below 28,500 MiB that local-coder-q6 will not fit (tested with the threshold raised; silent at 30,655 MiB free) |

Not tested: the `/model` picker row in an interactive session on the PC and on the Mac (the Mac needs the new `config/claude-settings.json`); tool-call reliability of the Q6_K beyond one ts-demo run; the speed cost of the larger quant in a long real session.

## Context overflow recovery, tried and reverted (TASK-021)

Question: does Claude Code recover from a local context overflow if the router reports it the way the Anthropic API does?

| Item | Finding |
|---|---|
| What Claude Code recognises (2.1.302, from its code) | An error whose message contains "prompt is too long" or "input is too long for requested model", at either status, is prompt-too-long; it parses "prompt is too long ... N tokens > M" to size the cut. Its embedded gateway protocol asks gateways to relay a 400/413 Anthropic envelope with "prompt is too long: ..." because auto-compact keys on it. llama-server's text ("request (N tokens) exceeds the available context size (M tokens)"), as passed on by LiteLLM, matches neither |
| Router change tried | A LiteLLM `CustomLogger.async_post_call_failure_hook` that rewrote, in place, the message of a local model's overflow to "prompt is too long: N tokens > M maximum" (LiteLLM 1.106.0's /v1/messages ignores an HTTPException returned by the hook but reads the exception message after it). At the router: oversized requests, streaming and not, answered 400 `{"type":"error","error":{"type":"invalid_request_error","message":"prompt is too long: 147047 tokens > 131072 maximum"}}`; normal requests 200, no key 401, a Claude model still answered |
| 16 parallel full Reads, both entries | Claude Code recognised the error and ran reactive compaction down to its last resort (head truncation, no trailing messages), then gave up: "last-resort request still too long" (174,578 > 131,072 and 210,621 > 163,840). The newest turn alone is larger than the window |
| Server-side overflow with history to drop (test settings: local-coder compaction window 160K over a 128K server, 8 full Reads) | Recognised 400 (147,608 > 131,072), reactive compaction summarised the older history, retry 147,748 tokens, turn ended: compaction keeps the newest turn verbatim, and that turn was the overflow |
| Two steps of 8 full Reads, repo settings | No server overflow: Claude Code compacted on its own estimate, then the local model returned an empty summary ("automatic compaction failed: summarization produced empty response", the TASK-015 failure mode) |
| Token counting | Router `/v1/messages/count_tokens` against llama-server's tokenizer on real files: 5-7% low (`proxy_server.py` 184,470 vs 198,153; `utils.py` 1.07; `install.ps1` 1.05; README 1.07). The synthetic test files are about 1.9 characters per Qwen token against about 4.5 for real Python, so the large undercount seen in TASK-020 belongs to the test text, not to real code |
| Outcome | Reverted as the task required (no recovery even from a recognised error). `config/litellm.yaml` is unchanged; the hook is kept for reference outside the repo at `D:\local-ai\scratch\ovr\overflow_errors.py.reverted`. After the revert, 8 full Reads and the ts-demo task pass on local-coder |

Remaining risk: one step whose tool results exceed the window (for example 16 parallel Reads at the 8K cap, about 128K tokens) ends the turn on either local entry. Not tried: a lower Read cap (16 x 6K would fit 128K), asking for fewer files per step, compaction reliability of the local model.

## Router key rotation (TASK-017)

| Step | Result |
|---|---|
| Before | Old key (SHA-256 prefix `54fc3c6c`) gets 200 on loopback and on the tailnet address |
| `init-secrets.ps1 -Rotate` | New key (`46b1b607`, 57 characters) stored; still one `local-ai/router-key` item in Credential Manager. The running router still takes the old key (200) and refuses the new one (401) |
| `ai-down` + `ai-up` | Old key 401, new key 200, on loopback and on the tailnet address; `claude-local.ps1` answers on local-coder and local-coder-q6 |
| Mac, before `setup-client.sh` | `claude-local.sh` fails with 401 (user) |
| Mac, after `copy-router-key.ps1` and `setup-client.sh` | `claude-local.sh` works, `/model` lists Local Coder Q6 and it answers (user); one Keychain item for `local-ai/router-key`, account = the Mac user. `grep -c` on `security dump-keychain` prints 2 for one item (label and service both match), so the procedure uses a per-item check |

The keys never left the PowerShell process that tested them: only status codes and hash prefixes were printed. Procedure in `docs/remote-client-macos.md` (Rotating the key).

## Tailscale serve in HTTP mode with identity headers (TASK-022, m-3 spike)

Tested with Tailscale 1.104.1 on the PC (node not tagged) and the Mac, using a header-echo listener on 127.0.0.1:4090 behind `tailscale serve --http 4000` (tailnet port 4000, the only one the ACL grant opens), then the real router behind the same mode.

| Check | Result |
|---|---|
| Identity from the Mac | `Tailscale-User-Login` = <user login>, `Tailscale-User-Name`, `Tailscale-User-Profile-Pic`, `Tailscale-Headers-Info`, `X-Forwarded-For` = the Mac tailnet IP, `X-Forwarded-Host`. The request reaches the listener from 127.0.0.1 |
| Identity from the PC through its own tailnet name | The same login: identity is per user, not per device; `X-Forwarded-For` (the device tailnet IP) is what tells devices apart |
| Loopback request on the PC | No identity headers |
| Forged headers (from the Mac and from the PC) | `Tailscale-User-Login: evil@example.com` arrives as the real login; a forged `Tailscale-App-Capabilities` is dropped |
| Addressing | HTTP mode routes by host name (`http://caps:4000`, `http://caps.tail0144cb.ts.net:4000`); a request to the tailnet IP gets 404 from tailscaled |
| Path routes | `--set-path /echo` forwards `/echo/sub/path?x=1` as `/sub/path?x=1`; `/` to the router and `/echo` to the listener worked side by side on one port |
| Backend down | A route whose target does not listen answers 502 Bad Gateway at once |
| Claude Code through HTTP mode | From the Mac (user) and the PC: local-coder and sonnet answer; streaming deltas arrive the same way as over loopback (sonnet 85 vs 86 deltas over about 3 s, local-coder 716 vs 668 over about 9.5 s). Sonnet looks like it prints at once because it finishes in about 3 s |
| HTTPS | Not enabled on the tailnet (`CertDomains` empty) |

Decisions for m-3:
- **HTTP, not HTTPS.** Tailnet traffic is already encrypted by WireGuard; HTTPS would need HTTPS certificates enabled in the admin console and would publish the machine name in public certificate-transparency logs; identity headers and Claude Code work over HTTP.
- **Clients use the MagicDNS name**, `http://caps.tail0144cb.ts.net:4000`, not the tailnet IP (404 in HTTP mode). The Mac URL changes in TASK-024.
- **One tailnet port, path routes:** `/` to the router (127.0.0.1:4000) and `/control` to the control service (TASK-025). The ACL grant (tcp:4000) stays as it is. The `/control` route has to exist while the stack is down, so it is set up with the control service (TASK-026); `ai-up` and `ai-down` add and remove only the `/` route (with the router route gone, the tailnet answers 404 for `/`).
- **The allowlist holds the user login (an email address)**, so it lives outside the repo (TASK-023).
- Accepted (user, 2026-10-19): programs on the PC can reach the loopback port and set identity headers themselves.

Go: m-3 can build on identity headers.

## Router accepts the Tailscale identity (TASK-023)

- `config/custom_auth.py` lets a request in when `Tailscale-User-Login` (case-insensitive) is on the allowlist, otherwise when the key matches as before, otherwise 401.
- The allowlist reaches the router process as `LOCAL_AI_ALLOWED_LOGINS`, set by `scripts/start-litellm.ps1`: the lines of `D:\local-ai\allowed-logins.txt` if that file exists, otherwise the login the PC itself is signed in to Tailscale with. Nothing about it is in the repo; with Tailscale signed out and no file it is empty, and the router is key-only.
- **Marker header.** LiteLLM forwards the client's Claude subscription token (`Authorization`) to Anthropic only when the request also carries `x-litellm-api-key`, with any value (`litellm_pre_call_utils.py`: without it, `Authorization` counts as the proxy credential and is dropped; there is no setting for this). Without it Claude models failed with "Missing Anthropic API Key" while local models worked. Clients that come in by identity therefore send `x-litellm-api-key: tailscale-identity`, a fixed non-secret value that never lets a request in by itself (loopback with the marker: 401).
- `ai-up` publishes the `/` route of tailnet port 4000 in HTTP mode, after removing a TCP forward left by the old version (TCP and HTTP cannot share the port), and prints `tailnet http://caps.tail0144cb.ts.net:4000`. `ai-down` removes only `/`, so the control service route stays.

| Check | Result |
|---|---|
| Unit test (fake requests) | 11/11: allowlisted login in any case, second login, other login refused, other login plus key allowed, no identity refused, key in either header, wrong key refused, empty allowlist means key-only |
| Through the tailnet name, no key | `/v1/models` 200; Claude Code with the marker: sonnet, local-coder and local-coder-q6 answer |
| Loopback | No key 401, forged `Tailscale-User-Login` 401, key 200; `claude-local.ps1` works |
| Allowlist file without the user login | Through the tailnet name: no headers 401, marker 401, key 200 |
| ai-up / ai-down | TCP forward replaced by the HTTP route; second ai-up starts nothing; ai-down keeps a `/control` route, also after a killed router |

Effect on clients: in HTTP mode the tailnet IP gets 404, so the Mac must use the MagicDNS name from now on (TASK-024 changes its setup).

## Mac client without the key (TASK-024)

- `scripts/mac/setup-client.sh <url>` takes only the router URL. It must be the MagicDNS name: an IP is refused, because in HTTP mode tailscale serve answers only on the name. The script saves the URL in `~/.config/local-ai/router-url`, removes any router key left in the Keychain by the key-based setup, and checks `/v1/models` with the marker header.
- `scripts/mac/claude-local.sh` sends `x-litellm-api-key: tailscale-identity` (the marker, not a secret) and no key. As before, it unsets `ANTHROPIC_API_KEY` and `ANTHROPIC_AUTH_TOKEN` for Claude Code.
- A key rotation is now done on the PC only (`docs/remote-client-macos.md`).

| Check | Result |
|---|---|
| `setup-client.sh` on the Mac | Removed 1 router key item from the Keychain. "Router reachable, and it accepts this Mac's Tailscale login" |
| Keychain afterwards | No `local-ai/router-key` item. The per-item check prints nothing (`grep -c` on the dump counted label and service, so it printed 2 for one item) |
| Claude Code on the Mac | A Claude model and the local models answer; `/model` lists every local entry |

## Browser requests refused on the identity path (TASK-031)

Gap left by TASK-023: tailscale serve attaches the user identity to every request from the device, also to requests made by a web page in the browser, and LiteLLM answers cross-origin requests permissively. Measured through the tailnet name with `Origin: https://evil.example`: CORS preflight 200 with `Access-Control-Allow-Origin: *`, `GET /v1/models` 200 and a `local-coder` chat 200, readable by the page. A malicious page that guessed the address (`http://caps:4000`) could have used the local models with admin rights on the router; Claude models were out of reach (the page has no subscription token).

Fix in `config/custom_auth.py`: a request that carries `Origin` or `Sec-Fetch-Site` (sent by browsers, never by Claude Code) is not let in by identity, only by the key.

| Check | Result |
|---|---|
| Unit test | 16/16, including identity + Origin, identity + Sec-Fetch-Site, identity + marker + Origin (all 401), Origin + key (allowed) |
| Through the tailnet name with the identity | Origin: GET /v1/models 401, POST to local-coder 401; Sec-Fetch-Site only 401; marker + Origin 401; Origin + key 200; no browser headers 200. The preflight still answers 200 (LiteLLM CORS middleware runs before auth), the request behind it is refused |
| Claude Code | Through the tailnet name with the marker: sonnet and local-coder answer; `claude-local.ps1` with the key answers |

The control service (TASK-025) applies the same rule.

## Control service (TASK-025)

- `scripts/control-service.py` uses only the Python standard library and runs under the LiteLLM venv's interpreter, on 127.0.0.1:4100. Routes: `GET /health` (no auth), `GET /status`, `POST /up` and `POST /down`. Up and down run `ai-up.ps1` and `ai-down.ps1` without parameters, so no `-Force` or `-Warm`; a query string is ignored. One action runs at a time; a second gets 409. A failed script gives 422 with its message. Every request is logged to `D:\local-ai\logs\control.log` (time, login, method, path, code, outcome).
- It lets requests in the same way as the router: an allowlisted `Tailscale-User-Login` and no `Origin` or `Sec-Fetch-Site`. There is no key path; at the PC, `ai-up` and `ai-down` are run directly.
- tailscale serve publishes it as `/control` on tailnet port 4000 and strips the prefix. It holds no GPU memory and never starts the stack by itself. `scripts/start-control.ps1 [-Stop]` starts or stops it.

| Check | Result |
|---|---|
| From WSL through the tailnet name | `/health` 200, status answered. Loopback without identity 401, `Origin` 401, `Sec-Fetch-Site` 401. `GET /up` 405, unknown route 404. `POST /up?Force=1` started the stack normally (query ignored). Up again: already running. Two concurrent ups: the second got 409 while status kept answering (running: up) |
| GPU | The service process holds 0 MiB |
| Game guard | With a stand-in game (a PING.EXE copy under `...\steamapps\common`): up 422 with the guard message |
| Mac (curl) | Status down, up ok in 13.4 s, status up, down with VRAM back to 1,606 MiB; up refused while the stand-in game ran |
| `ai-down` | Keeps the `/control` route |

## Control service started at logon (TASK-026)

- `scripts/install-control.ps1` registers the scheduled task `local-ai-control` without elevation: triggered at logon of the user and repeated every 10 minutes for an indefinite duration (since TASK-032 the 10-minute check is a separate time trigger, see below). It runs `conhost.exe --headless powershell.exe … start-control.ps1`, so no console window opens. start-control.ps1 does nothing while the service runs, so the repetition only matters after a crash. The script also starts the service once and publishes `/control` on tailnet port 4000, which tailscale serve keeps across reboots. `-Uninstall` stops the service and removes the task and the route. Both are safe to run twice, and neither starts the AI stack.
- It is a scheduled task rather than a Windows service because the service runs as the user: ai-up reads the router key from the user's Credential Manager. The PC must be on with the user logged in (Wake-on-LAN is out of scope).
- **Logon race.** The task runs within seconds of logon, before Tailscale is signed in, so Get-AllowedLogins returned nothing and the service refused the Mac (the first logoff test got 401). The repetition cannot fix this, because the service is already running. `control-service.py` now re-reads the allowlist through Get-AllowedLogins on demand: every 60 s, every 5 s while it is empty, and on the first request if it started empty. A changed `allowed-logins.txt` also applies without a restart. A 401 says when the PC has no allowed logins. The router reads the list only once, at start; `start-litellm.ps1` now warns when that list is empty.
- ACL unchanged: `/control` is a path on tailnet port 4000, already covered by the `autogroup:member → autogroup:self tcp:4000` grant.
- `install.ps1 -CheckOnly` prints a `control` line (task registered, service running, `/control` published). It is a report only, never an install step.

| Check | Result |
|---|---|
| Install twice, uninstall twice | Second install: service already running. Second uninstall: nothing to remove |
| Scheduled task | Ready, logon trigger for the user, repetition PT10M indefinite. The service keeps running after the task ends and after Stop-ScheduledTask. No window |
| Empty allowlist at start (simulated) | First request 200, ALLOWLIST logged. `allowed-logins.txt` without the login: 401 within 35 s. File removed: 200 within 65 s |
| Logoff and logon, before the fix | Service up 3 s after logon with 0 allowed logins. Mac: 401 |
| Logoff and logon, after the fix | Logon 23:36:17, service started 23:36:19 with 0 logins. First Mac request at 23:37:17 re-read the list (1 login): status 200, up 200 (Stack healthy in 14.3 s), down 200. The stack stayed down until up |
| Repetition | Service killed at 23:39:28. The task run at 23:46:17 (10 minutes after logon) brought it back at 23:46:18 with 1 allowed login |
| `install.ps1 -CheckOnly` | Shows "not installed" or "installed, running, /control published" |

The repetition followed a 10-minute grid counted from logon, so a crashed service was back within 10 minutes, but only after a logon: a reinstall left nothing scheduled until the next one (fixed in TASK-032).

## ai-remote on the Mac (TASK-027)

- `scripts/mac/ai-remote.sh status|up|down` calls `<router-url>/control/<command>` with no key. The URL comes from the file written by `setup-client.sh`, or from `LOCAL_AI_ROUTER`. The JSON answer is rendered by `osascript -l JavaScript`, which every Mac has, so it needs neither jq nor Python. Exit status: 0 done, 1 refused or failed on the PC, 2 usage or no URL, 3 PC not reachable.
- Messages by cause: the name does not resolve (curl exit 6: Tailscale is off on the Mac). The connection times out (the PC is asleep or off, Tailscale is off there, or nothing is published on port 4000; the PC's firewall drops connections to an unpublished port, so these cases look the same). 502 (control service not running), 404 (`/control` not published while `/` is), and 401, 409 and 422 from the service.
- **Cut error messages.** The control service kept only the first stderr line of a failed script. `powershell -File` prints a throw as an error record wrapped at the console width (120 columns), so the longer guard message came back cut. The scripts now run inside `try { & script; exit 0 } catch { [Console]::Error.WriteLine($_.Exception.Message); exit 1 }`, which returns the exact message.
- The ai-up guard message now ends "Close the game or free the GPU, then try again (at the PC, -Force starts anyway)", since `-Force` cannot be passed remotely. The PC-side "Use: ..." hint of `ai-up` is not shown on the Mac.

| Check | Result |
|---|---|
| From WSL through the tailnet name (`osascript` replaced by node) | Every message above, plus a port taken by another process (422) and a foreign `allowed-logins.txt` (401, then 200 after removing it) |
| Mac | Status, up (13.2 s), up again ("Nothing started"), status, down, and Tailscale off on the Mac |
| Not tested | A PC that is really asleep (TASK-029) |

## decision-008: remote devices by Tailscale login, control service (TASK-028)

The backlog CLI can set only a decision's title and status, so the body of decision-008 is kept here.

**Context.** After m-2, each remote device held a copy of the router key (decision-005). It was set up from the PC (`copy-router-key.ps1` and the Mac Keychain), and the stack could be started only at the PC (`ai-up`). Away from home, neither works. The tailnet already knows which user each device belongs to, and the ACL lets only the user's own devices reach port 4000 (TASK-013).

**Decision.**
- `tailscale serve` publishes tailnet port 4000 in HTTP mode instead of a TCP forward (decision-006). It adds `Tailscale-User-Login` to each request and overwrites one sent by the client. The route `/` goes to the router (published by `ai-up`, removed by `ai-down`); `/control` goes to the control service (published by `install-control.ps1`, kept across reboots).
- The router (`config/custom_auth.py`) and the control service let a request in when its login is on the allowlist and it carries neither `Origin` nor `Sec-Fetch-Site`, which browsers send (TASK-031). The allowlist is `D:\local-ai\allowed-logins.txt` if it exists, otherwise the login the PC is signed in to Tailscale with. It stays outside the repo.
- The router key stays for calls made on the PC (`claude-local.ps1`), and works from any client as before; remote devices do not need it. Clients that come in by identity send the non-secret marker `x-litellm-api-key: tailscale-identity`, because LiteLLM forwards the Claude subscription token only when that header is present.
- The control service (127.0.0.1:4100) runs `ai-up` and `ai-down` on request and does nothing else. A scheduled task starts it at logon and every 10 minutes. The AI stack itself never starts by itself (PRD F4). On the Mac: `ai-remote.sh status|up|down`.

**Consequences.**
- A Mac is set up with the URL alone, with nothing to do on the PC, and a key rotation no longer touches it.
- Clients must use the MagicDNS name: in HTTP mode the tailnet IP gets 404.
- Programs on the PC can reach the loopback ports and set the identity header themselves. The user accepted this (TASK-022): such a program runs as the user and can read the key from Credential Manager anyway.
- Any device signed in with the user's Tailscale login can use the router and start or stop the stack. The ACL (`autogroup:self`) and the allowlist are the boundary.
- The router reads the allowlist only when it starts, so after changing `allowed-logins.txt` the stack must be restarted. The control service re-reads it every 60 s.
- The PC must be on with the user logged in. A sleeping PC cannot be woken (Wake-on-LAN is out of scope), and remote start needs `install-control.ps1` to have been run once.
- Still one port and the same ACL grant: nothing new is published on the tailnet.
- Idle shutdown of the stack is out of scope; llama-swap still unloads the model after 300 s.

## Exposure check and secret scan after m-3 (TASK-028)

PC addresses: Wi-Fi 192.168.1.101, WSL vEthernet 172.21.160.1, NordLynx 10.5.0.2, Tailscale 100.111.199.22.

| Check | Result |
|---|---|
| Listeners, stack down | Control service 127.0.0.1:4100. tailscaled on 100.111.199.22:4000 and the IPv6 tailnet address, plus its own peer API ports (41431, 61944) on the tailnet addresses |
| Listeners, stack up (`ai-up -Warm`, then `local-coder-q6` loaded) | Router 127.0.0.1:4000, control service 127.0.0.1:4100, llama-swap 127.0.0.1:8080, llama-server 127.0.0.1:10001 and 127.0.0.1:10002. Nothing from the stack on a non-loopback address in either state, apart from tailscaled on the tailnet addresses |
| tailscale serve | Port 4000 only, HTTP mode. Stack down: `/control` -> 127.0.0.1:4100. Stack up: also `/` -> 127.0.0.1:4000. Funnel off |
| Probes from WSL | Tailnet address: 4000 open; 4100, 8080, 10001 and 10002 closed. Wi-Fi and NordLynx addresses: all five closed |
| nmap from the Mac, tailnet name, stack up with `local-coder` loaded (`nmap -Pn -p 4000,4100,8080,10001-10010`) | 4000 open; 4100, 8080 and 10001-10010 filtered. A chat request to `local-coder` with the marker and no key: 200 |
| nmap from the Mac, Wi-Fi address 192.168.1.101, Tailscale off on the Mac, stack up | All 13 ports filtered |
| nmap from the Mac, tailnet name, stack down (`ai-remote.sh down`, VRAM 22,697 -> 1,348 MiB) | 4000 open (the `/control` route keeps it published); all others filtered |
| Secret scan (73 tracked files, 35 commits, `git log --all -p`) | Pattern hits only name prefixes, in docs and in `init-secrets.ps1`; no token values. No tracked `.env`, `.key`, `.pem`, `.p12` or `.pfx` files, and `allowed-logins.txt` is not tracked. The user's email is in no tracked file and no patch |
| Router key (exact match inside PowerShell, count only) | In 0 of 73 tracked files, not in the history, in 0 of 76 worktree files (ignored ones included), in 0 of 50 log files |

## Control service restart schedule (TASK-032)

Found while preparing TASK-029. The 10-minute repetition sat on the at-logon trigger, and a logon trigger's repetition starts only at a logon. `install-control.ps1` registers the task again on every run, so after an install nothing was scheduled until the next logon (`NextRunTime` empty). After a reinstall at about 23:55 on 2026-10-19, the runs at 23:56, 00:06 and 00:16 did not happen. A crash in such a window would have kept the service down until someone logged on at the PC. The TASK-026 test missed this because it logged off and on after installing.

Fix: the task has two triggers. The logon trigger, without a repetition, starts the service right after a logon. A time trigger starts at install time and repeats every 10 minutes for an indefinite duration. A time trigger keeps its schedule across logons and reboots, and runs while the user is logged on.

| Check | Result |
|---|---|
| Install twice | Next check at 00:33, then 00:34, 10 minutes after each install, with no logon |
| Triggers | Logon trigger for the user, no repetition. Time trigger from the install time, PT10M, indefinite |
| Killed service | Killed at 00:24:19. The time trigger ran at 00:34:04 and the service was back at 00:34:05 with 1 allowed login, with no logon in between. Next check set to 00:44:03 |
| Uninstall twice, install | The second uninstall found nothing to remove. After the install the next check was 10 minutes out, and `install.ps1 -CheckOnly` reported "installed, running, /control published" |
| Stack | Down throughout |

## Acceptance run away from home (TASK-029, m-3)

The user ran the plan from the Mac on another network on 2026-10-21 and reported that every step passed. The PC side was checked afterwards from its logs.

| Check | Result |
|---|---|
| Fresh client setup | `router-url` removed, `setup-client.sh` with the URL and no key; nothing done at the PC (user report) |
| `ai-remote.sh up` | Control log 09:53:41: `POST /up 200`, stack healthy in 16.8 s, by the user's login. The allowlist was empty when the service started at logon (07:47:20) and held 1 login when read again at 09:53:23, before the first request |
| Claude Code | `/model` listed Claude and local models; local-coder and a Claude model answered; the `ts-demo` edit completed with local-coder (user report). Router 09:53-16:57: 867 requests from the Mac's tailnet address, 833 answered 200 |
| `ai-remote.sh down` | Control log 16:58:41: `POST /down 200`, tailnet publishing, router and llama-swap stopped. Status then showed the stack down (user report). Checked at the PC afterwards: VRAM 1,607 MiB, `tailscale serve` publishes only `/control` |
| Errors seen by the router, not visible to the user | 29 x 429 from api.anthropic.com (subscription rate limit; Claude Code retries these). 8 x 500 on `/v1/messages/count_tokens` for local models: LiteLLM's token counter fails on some tool schemas (`KeyError: 'items'`) and llama-swap has no `/v1/responses/input_tokens` (404) |
| Not tested | A PC that is really asleep (sleep on AC was set to never for the run; Wake-on-LAN is out of scope) |

## Qwen3.8 with MTP, trial entry (TASK-033, m-4)

`local-coder-38` serves unsloth `Qwen3.8-27B-UD-Q6_K.gguf` (21,983,677,344 bytes, SHA-256 in `scripts/versions.psd1`) with MTP speculative decoding: `--spec-type draft-mtp --spec-draft-n-max 3`, draft KV cache q8_0, 160K window, `--parallel 2 -kvu`, port 10002 (llama-swap gives ports in alphabetical order of the model names, so `local-coder-q6` moved to 10003; corrected in TASK-034). The MTP head is inside the GGUF (`blk.64.nextn.*`); the Qwen3.6 GGUFs have none. Qwen/Qwen3.8-27B `config.json` is identical to Qwen3.6-27B's, so the pinned llama.cpp b11719 runs it unchanged. The Qwen3.6 entries are unchanged.

Measured against a bench llama-swap (`D:\local-ai\scratch\q38`), unlike TASK-020 with real Python source as the long prompt (LiteLLM's proxy package) and a ~1,200-token code answer, Qwen's thinking sampling (temperature 1.0, top_p 0.95, top_k 20), median of 3 for short prompts. VRAM includes the desktop (about 1.6 GB idle, 32,607 MiB total).

| Setup, 160K | VRAM, model loaded | Generation: short / 94K / 161K prompt (tok/s) | MTP acceptance | Main answer / second request arriving 3 s later |
|---|---|---|---|---|
| Qwen3.6 Q6_K, 2 slots (local-coder-q6) | 29,438-29,487 MiB | 61.9 / 47.5 / 40.8 | - | 21.8 s / 3.8 s |
| Qwen3.8, no MTP, 2 slots | 28,516 MiB | 63.5 / 49.1 / 41.7 | - | 22.5 s / 3.1 s |
| Qwen3.8, no MTP, 1 slot | 28,372 MiB | 64.5 / 49.7 / - | - | 23.1 s / 20.1 s |
| Qwen3.8, draft 2, 1 slot | 30,229-30,263 MiB | 131.3 / 86.0 / 67.0 | 0.85-0.88 | 13.5 s / 10.5 s |
| Qwen3.8, draft 2, 2 slots | 30,677-30,709 MiB | 132.1 / 87.5 / - | 0.88 | 15.7 s / 4.5 s |
| Qwen3.8, draft 3, 1 slot | 30,379-30,413 MiB | 149.0 / 100.7 / 80.7 | 0.79-0.83 | 12.1 s / 9.0 s |
| **Qwen3.8, draft 3, 2 slots (trial entry)** | 30,833-31,001 MiB | 152.7 / 91.6 / 78.8 | 0.70-0.83 | 15.4 s / 4.9 s |
| Qwen3.8, draft 4, 1 slot | 30,424-30,529 MiB | 157.0 / 104.5 / 79.0 | 0.69-0.76 | 11.9 s / 8.9 s |
| Qwen3.8, draft 4, 2 slots | 31,138-31,168 MiB | 155.3 / 103.5 / - | 0.73-0.75 | 10.5 s / 3.5 s |

Prompt processing: Qwen3.6 2,075 tok/s at 98K and 1,571 at 161K; Qwen3.8 without MTP 2,179 and 1,610; with MTP about 5% lower (2,039-2,078 at 94K, 1,510-1,535 at 161K). Thinking output (reasoning_effort low) speeds up like code: 132, 147 and 156 tok/s at drafts 2, 3 and 4. Draft 3 was chosen: as fast as 4 at a full prompt, with higher acceptance there (0.83 vs 0.69).

| Window, draft 3 | VRAM | Free | Near-full prompt |
|---|---|---|---|
| 128K, 1 slot | 28,770-28,794 MiB | 3.8 GB | 129,485 tokens: pp 1,726, tg 87.0 tok/s |
| 128K, 2 slots | 29,368-29,392 MiB | 3.2 GB | 129,486 tokens: tg 85.1 tok/s |
| 160K, 1 slot | 30,379-30,413 MiB | 2.2 GB | 161,492 tokens: tg 80.7 tok/s |
| **160K, 2 slots** | 30,833-31,001 MiB | 1.6 GB | 161,497 tokens: pp 1,535, tg 78.8 tok/s |
| 192K, 1 slot | 31,722-31,746 MiB | 0.9 GB | 194,730 tokens: pp 1,367, tg 70.4 tok/s |

160K is the largest window that leaves about 1.5 GB for the desktop; 192K leaves 0.9 GB. Every setup stays far above N1 (about 40 tok/s) at a full prompt. ai-up warns below 30,200 MiB free that local-coder-38 will not fit.

**Slot count, for the user.** One slot is about 10% faster at a 94K prompt (100.7 vs 91.6 tok/s) and uses 0.4-0.6 GB less VRAM. Two slots let a second request in at once: it took 4.9 s instead of 9.0 s, while the main answer took 15.4 s instead of 12.1 s. Second requests come from subagents or a second session (Claude Code's own background calls go to Haiku, TASK-005). The trial entry runs two slots, as today.

**Chat template.** The GGUF ships unsloth's template, not Qwen's: it merges leading system/developer messages and drops the "No user query found" assertion, but still raises "System message must be at the beginning." for a later system message. Claude Code through LiteLLM hit it on the first request (500 from the router, llama.cpp #27107). `config/qwen3.8-chat-template.jinja` is that template with one change: such a message is rendered as its own system turn (the Qwen3.6 unsloth template silently drops it instead). llama-swap passes it with `--chat-template-file ${env.LOCAL_AI_REPO}\config\...`; ai-up sets `LOCAL_AI_REPO`.

| Check | Result |
|---|---|
| Install | `install.ps1` downloaded and hash-verified the file; `-CheckOnly` lists all three models [ok] |
| ts-demo (discountPercent with RangeError, `Cart.count()`, tests, `npm test`) through the router with `claude -p` on the PC | Done in 74 s, 12 tool calls, no tool errors and no wrong-path first Read; edits correct; 7/7 tests pass. The prompt is kept at `D:\local-ai\scratch\q38\tsdemo-prompt.txt` for TASK-034 |
| Ports and stack scripts | The ai-up pre-check and ai-down cover 10001-10003. First recorded as port 10003; it is 10002, and Q6 moved to 10003 (TASK-034 fixed the labels and the control service's port map) |

Not tested here: the Mac (needs the pushed config), quality beyond one ts-demo run and the reported long-thinking loops (TASK-034), OpenCode (TASK-035).

## Quality check: Qwen3.8 vs Qwen3.6 (TASK-034, m-4)

A small version of the PRD bake-off (section 6, R4 gate), kept in `bench/quality/` so it can be re-run: seven tasks (README there has the prompts, fixtures, hidden tests and rubrics), each run twice per model in Claude Code through the router on the PC (`claude -p`, the repo's `claude-settings.json`, the full default tool list, the same allowed tools). `local-coder-q6` (Qwen3.6 Q6_K) against `local-coder-38` (Qwen3.8 UD-Q6_K, MTP draft 3), both at 160K with 2 slots. Run data: `D:\local-ai\scratch\quality\runs`.

| Task | Qwen3.6 Q6_K: pass, time (s) | Qwen3.8 + MTP: pass, time (s) |
|---|---|---|
| t1 ts-demo edit (hidden tests) | 2/2, 82 / 77 | 2/2, 63 / 47 |
| t2 multi-step edit: rename, coupon module, tests (hidden tests) | 2/2, 100 / 99 | 2/2, 112 / 145 |
| t3 review of the TASK-033 diff, 3 seeded bugs | 2/2: 3/3 bugs both times; one weak extra claim each (autoCompactWindow) | 2/2: 3/3 bugs both times; run 2 also claimed a missing `--draft-model` (wrong); 333 / 797 s |
| t4 PR description (rubric) | 1/2: run 2 invented test results ("confirmed ai-down stops all three ports") | 1/2: run 1 invented a start/stop test; run 2 the best of the four |
| t5 logic puzzle, no tools | 2/2, 68 / 70 | 2/2, 110 / 68 |
| t6 400-line module + 30 tests, full tool list | 2/2, 233 / 244 | 2/2, 592 / 844 |
| t6c the same, short tool list | 2/2, 240 / 289 | 2/2, 696 / 493 |
| **All** | **13/14, 32 min** | **13/14, 76 min** |

| Measure | Qwen3.6 Q6_K | Qwen3.8 + MTP |
|---|---|---|
| Tool-call failures (R4 gate: under 5%) | 33 of 171 calls, 19% (31 "File does not exist": the wrong-path Read seen since m-1) | 4 of 182 calls, 2.2% (2 WebSearch without permission, 2 Write calls with broken JSON after the output cap) |
| Failed test runs inside a task (normal iteration, not counted above) | 4 | 8 |
| Generation speed in Claude Code (52-66K prompts) | 52.6-62.2 tok/s | 93.9-141.4 tok/s, MTP acceptance 0.67-0.88 |
| Output tokens, whole set | 82,278 | 430,165 |
| Requests that hit Claude Code's 32,000 output-token cap | 0 | 5 (t3 run 2, t6 runs 1 and 2, t6c run 1) |

**Thinking.** LiteLLM forwards Claude Code's requests to llama-swap as `/v1/responses` and drops the `thinking` and effort parameters, so both models think at their template default; for Qwen3.8 that is `reasoning_effort` xhigh. The reasoning comes back from llama.cpp but LiteLLM does not turn it into thinking blocks, so Claude Code shows nothing while the model thinks. Qwen3.6 thought little (750-21,657 characters per run). Qwen3.8 thought 4-50 times as much, and on the long tasks it drafted whole files inside its reasoning before calling Write. Four of the five capped requests are that: 74-117K characters of drafting with low repetition, then the cap; Claude Code asks to continue and the work is partly redone. That is why t3 and t6 take 2-3 times as long on Qwen3.8 although it generates twice as fast, and it fits the lag spikes the user saw from the Mac (single requests of 4-5 minutes with no visible output).

**Long-thinking loop: confirmed, rare.** One request in 14 Qwen3.8 runs (t3 run 2) fell into a degenerate loop: after 14K characters of normal reasoning about the chat template's escape sequences it repeated `\n` for 41K characters until the cap; the run still finished with a correct review. In t3 run 1 the model quoted the template's think tags, the reasoning parser ended the thinking there, and 53K characters of reasoning landed in the visible answer (the review at its end was correct). Both happened while reviewing a chat template; no other request showed either.

**Many-tools slowdown: not seen at a size that matters.** Long answers (2,000+ tokens) with Claude Code's full tool list against the short list: Qwen3.8 106.4 / 106.5 against 116.4 / 113.3 tok/s (about 7% slower), Qwen3.6 53.9 / 53.9 against 55.8 / 55.5 (about 3%). Prompts were 52-66K tokens, so the speeds sit between TASK-033's bench figures for short and 94K prompts. llama.cpp #27615's slowdown on long outputs does not show here.

**Recommendation.** Qwen3.8 is the better coding agent: it passes the R4 tool-call gate (2.2% against 19%) with the same pass rate, finds the same bugs, and is about twice as fast per token; on short tasks (t1) it also finishes sooner. Its weakness is thinking at xhigh: long tasks take much longer, five requests ran into the 32K cap and one looped. Proposed: replace Qwen3.6 with Qwen3.8 in TASK-036, with a lower default `reasoning_effort` in the llama-swap entry (`--chat-template-kwargs`), after a short re-run of t1-t3 and t6 to check that quality holds at the lower effort. The user decides.

## OpenCode as the client for local models (TASK-035, m-4)

OpenCode 1.19.3 (npm `opencode-ai@1.19.3`, pinned: 1.19.4 came out on the day of the trial; `autoupdate` off, sharing off) on the PC, with `config/opencode.json`: one OpenAI-compatible provider `local-ai` on the router (`{env:LOCAL_AI_ROUTER_URL}/v1`, the router key from `{env:LOCAL_AI_ROUTER_KEY}`), entries `local-coder-38` and `local-coder-q6` at 160K context and 32,000 output tokens. It connects through the router rather than llama-swap: the router is the only service the Mac can reach (tailnet port 4000) and it does the auth; its OpenAI chat route passes `reasoning_effort` on and returns the reasoning, unlike the `/v1/messages` route Claude Code uses. The quality set (TASK-034) was run with `bench\quality\run-all.ps1 -Client opencode`: `opencode run --format json --auto`, web access denied as in the Claude Code runs, no tools for t5, t6c left out (OpenCode's tool list is already short: bash, edit, glob, grep, read, skill, task, todowrite, webfetch, write). Run data: `D:\local-ai\scratch\quality\runs` (`oc-*`).

**Context at session start** (same model, same ts-demo copy, from llama-swap's captures):

| Client | First request | Later requests |
|---|---|---|
| OpenCode | 10,954-11,183 tokens: 10 tools (21.7K characters), system prompt 21.7K characters | grow with the work only |
| Claude Code (repo settings) | 21,155-21,313 tokens (49,290 in one run where the connectors were already loaded): 24 tools, system prompt 6.5K characters | 49-52K from the second request: Claude Code adds the user's claude.ai connectors (Gmail, Calendar, Drive, Docs: 58 tools, about 31K tokens, plus their instructions) |
| Claude Code, `ENABLE_CLAUDEAI_MCP_SERVERS=false` | 21,255 tokens | 21.6-24.1K over a whole t1 run (24 tools, no connector tools) |

The connector finding matters beyond size: in a local session the local model is offered tools such as Gmail send and Drive share. TASK-020's 67K at an interactive start is probably this 52K plus what an interactive session adds.

**Quality set, OpenCode against Claude Code (TASK-034 runs; t1-t6, two runs each; pass, time in seconds):**

| Task | Qwen3.6 Q6_K, Claude Code | Qwen3.6 Q6_K, OpenCode | Qwen3.8 + MTP, Claude Code | Qwen3.8 + MTP, OpenCode |
|---|---|---|---|---|
| t1 ts-demo edit | 2/2, 82 / 77 | 2/2, 51 / 55 | 2/2, 63 / 47 | 2/2, 43 / 27 |
| t2 multi-step edit | 2/2, 100 / 99 | 2/2, 102 / 80 | 2/2, 112 / 145 | 2/2, 68 / 50 |
| t3 review, 3 seeded bugs | 2/2, 170 / 107 | 2/2, 36 / 34: 2/3 and 3/3 bugs, no wrong claims | 2/2, 333 / 797 | 0/2, 52 / 37: no answer (below); 0/2 again in two extra runs |
| t4 PR description | 1/2, 64 / 58 | 1/2, 39 / 34: run 1 invented a check ("verified the stack starts and stops cleanly") | 1/2, 133 / 112 | 2/2, 55 / 57 |
| t5 logic puzzle, no tools | 2/2, 68 / 70 | 2/2, 66 / 40 | 2/2, 110 / 68 | 2/2, 62 / 65 |
| t6 400-line module + 30 tests | 2/2, 233 / 244 | 2/2, 198 / 206 | 2/2, 592 / 844 | 2/2, 528 / 1,276 |
| **All** | **11/12, 22.9 min** | **11/12, 15.7 min** | **11/12, 55.9 min** | **10/12, 38.7 min** |

| Measure | Qwen3.6, Claude Code | Qwen3.6, OpenCode | Qwen3.8, Claude Code | Qwen3.8, OpenCode |
|---|---|---|---|---|
| Tool-call failures (failed test runs not counted) | 30 of 141, 21% (28 "File does not exist") | 1 of 120, 0.8% (a Glob on a wrong path) | 4 of 152, 2.6% | 2 of 177, 1.1% (a Read on a wrong path; a Write cut off at the 32K cap) |
| Largest prompt, t1-t4 | 52-67K | 14-28K | 54-78K | 15-35K |
| Generation speed per run | 52.6-62.2 tok/s | 58.7-62.3 tok/s | 93.9-141.4 tok/s | 109.7-149.5 tok/s |
| Output tokens, t1-t6 | 55,988 | 49,149 | 302,702 | 244,208 |
| Requests at the 32,000 output cap | 0 | 0 | 3 | 1 |

OpenCode's failure counts include calls it could not parse (it reports them as tool `invalid`; `run.ps1` counts them since this task). The Claude Code figures are TASK-034's without the t6c control, so they differ slightly from that section.

**Why Qwen3.8 gave no answer on t3 in OpenCode.** In all four runs the model read the chat template from the fixture and quoted it in its reasoning; where the template has `<|im_start|>` / `<|im_end|>` it wrote the real control token, and the end-of-turn token ended the generation (`finish_reason: stop` in the middle of a sentence, empty answer). Before stopping, run 1's reasoning had found all three seeded bugs. Claude Code met the same thing in TASK-034 (quoted think tags put the reasoning into the answer, one loop) but still returned a review. This is a model and server issue with text that contains the model's own control tokens, not an OpenCode one; it affects work on chat templates in either client.

**Thinking and effort.** OpenCode keeps the reasoning as its own parts (199 reasoning parts in its session database after the runs), so its interface shows the model thinking, where Claude Code through LiteLLM shows nothing during 4-5 minute requests. The effort can be set per model in `opencode.json` (`"options": {"reasoningEffort": "low"}`): the request then carries `reasoning_effort`, and llama.cpp renders it into the Qwen3.8 template (low and xhigh each add their own system line; medium adds none). One t5 run at low effort was correct with 5,112 output tokens, against 7,741 / 8,723 at the default xhigh. Claude Code cannot set it through the router (TASK-034), so for Claude Code the default must sit in the llama-swap entry (TASK-036).

**Compaction** (t6, one run each with a smaller window so that it must compact):

| Run | Window | Compactions | Result |
|---|---|---|---|
| OpenCode, Qwen3.8, repo config (run 2 above) | 160K, compacts at about 132K (context minus the 32K output limit) | 1 | Pass, 1,276 s; the long time is the model rewriting the module four times to get near 400 lines |
| OpenCode, Qwen3.8 | 82K, compacts at 50K | 1 | Pass, 403 s, no tool failures |
| OpenCode, Qwen3.6 | 82K | 0 (largest prompt 32K) | Pass, 269 s |
| Claude Code, Qwen3.8 | 100K: 80K effective, compacts at 64K | 1 (72.9K to 10.3K, 101 s) | Pass, 904 s |
| Claude Code, Qwen3.6 | 100K | 4 (each about 65K to 9-16K, 36-62 s) | Pass, 782 s; 8 tool failures (5 Edits on text that was not in the file, 3 wrong-path Reads) besides 5 failed test runs |

All six compactions produced a summary and the work went on; the empty summary of TASK-015 / TASK-021 did not show. Claude Code's 49-52K of fixed prompt sits outside what compaction can shrink, so in the smaller window it was back at the threshold after one or two steps. At the real 160K window that fixed part leaves Claude Code about 63K of working room before it compacts (115K threshold), against about 120K for OpenCode (132K threshold, 11K fixed).

**Mac path, checked from the PC.** OpenCode through the tailnet name (`http://caps.<tailnet>.ts.net:4000`) with the key replaced by the marker `tailscale-identity`, and with a wrong value: both answered, let in by the Tailscale login, so OpenCode sends no browser headers (TASK-031) and needs no key on the Mac.

**Verdict against PRD O1** (adopt for local models on about 15+ points of pass rate or half the tool failures): **met on tool failures, not on pass rate.** Tool failures fall from 21% to 0.8% on Qwen3.6 and from 2.6% to 1.1% on Qwen3.8 (halved, but 4 against 2 calls). Pass rate is the same on Qwen3.6 (11/12) and one task lower on Qwen3.8 (10/12, the t3 control-token stop above). Beyond the bar: the set takes about 30% less time in both models, the prompt at start is 11K instead of 21K (52K with the connectors), compaction has twice the working room, the thinking is visible, and the effort can be chosen per model. Against it: a second client to install and keep pinned, Claude models stay in Claude Code (subscription logins are blocked in third-party tools), and the interactive interface was not tried. **Decided (user, 2026-10-23): OpenCode is the client for local models; Claude Code stays for Claude models and remains usable as a fallback for local ones.** The claude.ai connectors stay enabled in Claude Code (`ENABLE_CLAUDEAI_MCP_SERVERS` is not set): with local work moving to OpenCode, Claude Code sessions are for Claude models, where the connectors are wanted. A local session in Claude Code still carries them (about 31K tokens, Gmail and Drive tools offered to the local model).

**What the Mac setup needs** for OpenCode:

1. OpenCode 1.19.3 pinned (`npm i -g opencode-ai@1.19.3`, or the release binary), recorded with the other pins; `autoupdate` stays off in the config.
2. The repo's `config/opencode.json` as is, with `LOCAL_AI_ROUTER_URL` from `~/.config/local-ai/router-url` (written by `setup-client.sh`) and `LOCAL_AI_ROUTER_KEY=tailscale-identity`, the non-secret marker; no key, no Keychain item.
3. A launcher `scripts/mac/opencode-local.sh`, the counterpart of `claude-local.sh`: sets `OPENCODE_CONFIG` and the two variables, then runs `opencode`; `ai-remote.sh up` beforehand as today.
4. The model entries in `opencode.json` matched to the router: `local-coder-38` and `local-coder-q6` at 163,840 tokens, `local-coder` and `local-light` at 131,072 if they are offered, and the chosen `reasoningEffort` per model (TASK-036).
5. A first check on the Mac: the interactive interface, the model picker, permission prompts (the runs here used `--auto`), and the reasoning shown while the model thinks.

Not tested: OpenCode's interactive interface on either machine, its LSP and formatter integrations, long real sessions, and more than one run per compaction case.

## decision-009: Qwen3.8 as the only local model, medium effort (TASK-036, m-4)

**Context.** TASK-034 found Qwen3.8 27B UD-Q6_K with MTP the better coding agent (tool-call failures 2.2% against 19%, the same pass rate, about twice the generation speed) but slow on long tasks, because it thinks at its template's default effort, xhigh. The user chose to replace Qwen3.6 with it, after a re-run of t1-t3 and t6 at a lower effort, and to keep one local entry under the existing name (2026-10-23). TASK-035 made OpenCode the client for local models; Claude Code stays for Claude models and as a fallback.

**Effort re-run** (Qwen3.8, OpenCode, `reasoningEffort` set per run; two runs each; xhigh from TASK-035):

| Effort | t1, t2, t6 pass | Time, t1-t3 and t6 | Output tokens | Reasoning characters | Requests at the 32K cap |
|---|---|---|---|---|---|
| medium | 6/6 | 16.4 min | 111,020 | 207,420 | 0 |
| "high" (rendered as xhigh, see below) | 5/6 | 19.5 min | 135,846 | 327,397 | 1: t6 run 2 thought 28K tokens before the first Write, hit the cap, and `opencode run` ended with no file |
| xhigh (template default) | 6/6 | 34.7 min | 217,060 | 494,851 | 1 |

t6 took 365 / 375 s at medium against 528 / 1,276 s at xhigh, with 41-47 tests and 452 lines. t3 returned no answer at every effort: the control-token stop described in the TASK-035 section, not an effort effect. t5 (the logic puzzle, the hardest thinking task) passed 2/2 at medium in 83 / 47 s. The template knows only low, medium and xhigh: `high` is mapped to xhigh, and any other value raises an error. Low was tried once on t5 (TASK-035, correct) and not on the coding tasks.

**Decision.** One local entry, `local-coder` (with `local-light` as its alias): Qwen3.8-27B-UD-Q6_K.gguf, MTP draft 3 with q8_0 draft cache, 160K context, 2 slots with `-kvu`, the patched chat template (TASK-033), and reasoning effort medium when a request does not name one. `local-coder-q6` and `local-coder-38` are removed, and both Qwen3.6 files leave the model list; the files stay on disk until the user deletes them. Supersedes decision-004 (128K).

**Consequences.**

- The default is set in `config/llama-swap.yaml` as `env: LLAMA_ARG_CHAT_TEMPLATE_KWARGS={"reasoning_effort":"medium"}`. As a `--chat-template-kwargs '{...}'` argument it failed: llama-swap on Windows passes the single quotes through and llama-server rejects the JSON. Checked with `/apply-template`: no effort renders the medium prompt (no reasoning line), a request's `reasoning_effort` low or xhigh, or its `chat_template_kwargs`, overrides it.
- Claude Code gets medium too: it cannot name an effort through the router, and a request without one gets the default on both llama-server routes. Measured by prompt length on `/v1/chat/completions` and `/v1/responses` alike: no effort 13 tokens, medium 13, low 43, xhigh 55. On t5 in Claude Code that did not show as less thinking (10,253 output tokens against 14,652 / 9,309 at xhigh in TASK-034); the puzzle thought about as much at medium in OpenCode too.
- VRAM: the model needs about 29.4 GB. `ai-up` still refuses below 22,000 MiB free (game guard, decision-007) and now warns below 30,200 MiB that the model will spill and run slowly. The idle desktop leaves 30,455 MiB free, so a GPU-hungry app open next to it brings the warning.
- One llama-server port, 10001: `ai-up`'s port check, `ai-down` and the control service's status cover only that one.
- Load time 12.3 s (`ai-up -Warm`, warm file cache).
- Claude Code: the picker lists Local Coder and Local Light; `modelSettings` is gone, since every local model now has the 160K window of `CLAUDE_CODE_MAX_CONTEXT_TOKENS`.
- `config/opencode.json` now names `local-coder`; `local-light`, the per-model effort and the launchers are TASK-038.

| Check | Result |
|---|---|
| `install.ps1 -CheckOnly` | Everything in place; model Qwen3.8-27B-UD-Q6_K.gguf for local-coder (20.5 GiB) [ok] |
| ts-demo (t1) and t5 through the router from the PC | Claude Code on local-coder: pass in 53 s, 11 tool calls, no failures, first prompt 21,210 tokens. OpenCode on local-coder: pass in 24 s, 13 tool calls, no failures, first prompt 10,911. t5 in Claude Code: pass in 89 s |
| Local Light and a Claude model, Claude Code through the router | local-light answered (served by the local-coder process); Sonnet answered |
| Control service over the tailnet (restarted) | `/control/status`: stack up, `model_loaded` local-coder |
| `ai-up` thresholds (raised for the test, 30,455 MiB free) | Warning threshold raised: starts and warns; refusal threshold raised: "Not starting: only 30455 MiB of VRAM free"; normal start healthy in 13.7 s |
| From the Mac | Not run: the user had no Mac at hand and asked to assume it works (2026-11-08), to debug later |

## OpenCode setup for local models (TASK-038, m-4)

OpenCode is the client for the local models and Claude Code the client for the Claude models (user, 2026-10-23, after TASK-035). Claude Code still lists the local models as a fallback.

- **Pin.** OpenCode 1.19.3 (npm `opencode-ai`) in `scripts/versions.psd1` and the README pin list, with the same pin on the Mac. `install.ps1` installs it with npm when it is missing and warns on another version. Node.js is a prerequisite that the scripts never install: a missing npm only warns. `autoupdate` is off in the config. Node 22.19.0 on the PC.
- **Config** (`config/opencode.json`):
  - Models: Local Coder (the default and the small model) and Local Light, each at 163,840 context and 32,000 output, with `reasoningEffort` medium. That is the server default from decision-009, and the request now carries it explicitly.
  - Permissions (user, 2026-10-23): edits are allowed. Shell commands ask, except read-only ones and test runs (git status/diff/log/show, ls, pwd, npm test, node --test). On Windows the shell is PowerShell, so its read-only cmdlets are allowed too (Get-ChildItem, Get-Content, Get-Item, Get-Location, Test-Path, Resolve-Path, Select-String, Select-Object, Measure-Object, and the aliases gci, dir, gc, cat, type, sls; added 2026-11-08 after the TUI check asked for a Get-ChildItem listing). OpenCode checks each part of a pipe or chain on its own and the last matching rule wins, so a last rule `*{*`: ask makes any command with a script block ask: a block can run any command inside an allowed cmdlet's argument. Web fetch is denied, so it is also left out of the tool list. `--auto` approves the asks for a session (the user asked for an auto mode; OpenCode's flag approves everything not denied and has no classifier).
  - Skills: OpenCode loads `~/.claude/skills` too. The eight synced skills that need Claude-only tools are denied by name (`permission.skill`): built-in-browser, chrome-browser, computer-use, deep-research, docs, google-workspace, import-memory, morning. The file skills and project skills still load.
- **Launchers.**
  - `scripts/opencode-local.ps1`: router URL from `LOCAL_AI_ROUTER` (default loopback), key from Credential Manager, both only in the OpenCode process and restored afterwards.
  - `scripts/mac/opencode-local.sh`: the URL saved by `setup-client.sh`, and the `tailscale-identity` marker as the key (TASK-035 checked that the router lets OpenCode in by Tailscale login alone).
  - Both set `OPENCODE_CONFIG` to the repo config and pass all arguments through.
  - `ai-up`, `ai-remote.sh up` and `setup-client.sh` now name both launchers, and `setup-client.sh` reports a missing or unpinned OpenCode.

| Check (PC) | Result |
|---|---|
| `install.ps1 -CheckOnly` | `OpenCode 1.19.3`, everything in place |
| Resolved config through the launcher (`debug agent build`) | The bash ask and allow rules, webfetch deny and the eight skill denies are in effect; both models are listed |
| t1 (ts-demo) through `opencode-local.ps1 run --auto` | Pass in 32 s: 11 tool calls, none failed, 10 tests. Request: `reasoning_effort: medium`; tools bash, edit, glob, grep, read, skill, task, todowrite, write (no webfetch). Skills in the prompt: docx, pdf, pptx, skill-creator, xlsx and OpenCode's built-in customize-opencode. First prompt 8,719 tokens, against 10,911 in TASK-036 |
| Shell asks, `run` without `--auto` | `npm test` ran without asking; `node -e ...` was asked and, since `opencode run` cannot prompt, rejected ("The user rejected permission to use this specific tool call") |
| Interactive interface (TUI) on the PC (2026-11-08, driven from tmux, `opencode-local.ps1` without `--auto`, fresh ts-demo copy) | t1 pass in 50.5 s: own tests 9/9, hidden grader 5/5. Reasoning shown as Thought lines; edits and `npm test` without a prompt; `Get-ChildItem` asked (Allow once ran it); `node -e` asked, Reject stopped the turn without running it |
| PowerShell rules, `run` without `--auto` (2026-11-08) | `Get-ChildItem -Recurse -File \| Select-Object -ExpandProperty FullName` ran without asking (each part matched its allow rule); `Get-ChildItem src \| Remove-Item -WhatIf` asked for the Remove-Item part and was rejected; `Get-ChildItem src \| Select-Object @{n='x';e={ ... }}` asked through the `*{*` rule and was rejected |
| Interactive interface on the Mac | Not run: the user had no Mac at hand and asked to assume it works (2026-11-08), to debug later |

Notes:

- From WSL, `opencode run` started through `powershell.exe` waits for stdin while stdin stays open. Close stdin (`< /dev/null`); run from a real console, nothing changes.
- The Mac guide still mentioned Local Coder Q6 and 22 GB of VRAM from before TASK-036. Corrected here.
