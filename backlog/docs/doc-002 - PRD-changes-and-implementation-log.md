---
id: doc-002
title: PRD changes and implementation log
type: other
created_date: '2026-10-18 17:08'
updated_date: '2026-10-19 14:17'
---
# PRD changes and implementation log

The PRD (doc-0001) stays as written on 2026-10-18. This log records where the implementation deviates from it or settles a question it left open, and where the evidence lives. Update it whenever a decision changes.

## Deviations from the PRD

| PRD | What changed | Why | Recorded in |
|---|---|---|---|
| Local context 64K (section 6, O4) | 128K for `local-coder` and `local-light`: llama-server `-c 131072`, and Claude Code compacts within it through `modelSettings.<model>.autoCompactWindow=131072`. `local-coder-q6` has 160K (`-c 163840`); `CLAUDE_CODE_MAX_CONTEXT_TOKENS=163840`, one value for every local model, matches the largest server (TASK-020) | At 64K Claude Code compacts at ~36K tokens and thrashed; 128K measured at 56 tok/s with a 94K prompt, 23.6 GB VRAM | decision-004, TASK-004, TASK-020 |
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
| O4 context size | Resolved: 128K for the Q4_K_M entries, 160K for `local-coder-q6` (TASK-020) |
| O1 alternative harness, O2 final model, O3 `local-light` model | Resolved by not running the bake-off: Claude Code, Qwen3.6 27B, alias. The Q6_K quant of the same model was added as `local-coder-q6` (TASK-020). Reopen only if tool-call failures become a daily problem |
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
