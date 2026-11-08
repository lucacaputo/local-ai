# local-ai

A local coding model on a Windows PC with an RTX 5090, used from OpenCode, or from Claude Code through `/model` next to the real Claude models. Started on demand, at the PC or from your Mac, reachable from your own devices over Tailscale, off when you game.

```
OpenCode (local models) or Claude Code (Claude models; local ones too), on the PC or a Mac
  -> router: LiteLLM, 127.0.0.1:4000, published on the tailnet as http://<pc>.<tailnet>.ts.net:4000/
     auth: a remote device's Tailscale login (allowlist), or the router key on the PC
       |- claude models (anthropic/*)  -> api.anthropic.com, on your subscription login
       |- local-coder, local-light     -> llama-swap 127.0.0.1:8080 -> llama-server 127.0.0.1:10001
                                          (Qwen3.8 27B UD-Q6_K with MTP, 160K context, unloads after 5 min idle)

ai-remote.sh (Mac)
  -> control service, 127.0.0.1:4100, published as .../control on the same port -> ai-up / ai-down
```

`local-light` is an alias of `local-coder` (same process, same weights). The model is Qwen3.8 27B at UD-Q6_K with MTP speculative decoding (draft 3) and a patched chat template; it replaced Qwen3.6 (Q4_K_M and Q6_K entries) after the quality check in `bench/quality/` (TASK-033, TASK-034, TASK-036). It thinks before answering; the default reasoning effort is medium (set in `config/llama-swap.yaml`; the template knows low, medium and xhigh), which a request can override.

Background and the reasons behind each choice: the PRD (`backlog/docs/doc-0001-PRD.md`), what changed from it (`backlog/docs/doc-002 - PRD-changes-and-implementation-log.md`) and `backlog/decisions/`.

## Requirements

Windows 11, an NVIDIA GPU with about 30 GB of free VRAM for `local-coder` (with its caches and the MTP draft it uses 29.4 GB; built and measured on a 32 GB RTX 5090), a current NVIDIA driver (CUDA 12.8 or newer, compute capability 12.0), PowerShell 5.1, Node.js 22.18 or newer (for OpenCode), and a Claude subscription logged in to Claude Code. `install.ps1` installs everything else. The agent sandboxes (m-5, in progress) also need Docker Desktop with the WSL2 backend, which `install.ps1` checks but does not install.

## Install (once)

```powershell
scripts\install.ps1            # binaries, LiteLLM venv, the model (22 GB), all hash-verified
scripts\install.ps1 -CheckOnly # report what is present or missing, change nothing (exit 2 if work is needed)
scripts\init-secrets.ps1       # create the router key in Windows Credential Manager
scripts\install-control.ps1    # optional: control service at logon, to start and stop the stack from other devices
```

`install.ps1` is safe to rerun. It installs missing `uv` and Tailscale with winget and OpenCode with npm, at the pinned versions (Tailscale needs a one-time sign-in afterwards). It never installs the NVIDIA driver or Node.js, and only warns about another OpenCode version. Everything lands in `D:\local-ai` (override with `-Root` or `LOCAL_AI_ROOT`), outside the repo.

`install-control.ps1` registers the scheduled task `local-ai-control` (at your logon and every 10 minutes, no elevation), which keeps the control service running, and publishes `/control` on the tailnet. The service starts or stops the stack only when a device asks. `install-control.ps1 -Uninstall` removes all of it, and `install.ps1 -CheckOnly` reports whether it is installed.

## Daily use

```powershell
scripts\ai-up.ps1          # start: llama-swap + router, tailnet publishing; healthy in about 15-20 s
scripts\opencode-local.ps1 # OpenCode against the local router, for the local models; all arguments go to opencode
scripts\claude-local.ps1   # Claude Code against the local router, for the Claude models; all arguments go to claude
scripts\ai-down.ps1        # stop everything and free the GPU (VRAM goes back to idle in a few seconds)
```

- `ai-up -Warm` loads `local-coder` immediately; otherwise the first local request loads the model (about 12 s). Local Light shares Local Coder's process, so switching between them is instant.
- `ai-up -NoTailnet` keeps the router on loopback only. `ai-up -Force` skips the game guard (at the PC only).
- The AI stack never starts by itself: not at boot, and the control service (if installed) starts it only when asked. The model unloads by itself after 300 s without requests; `ai-down` also stops the processes.
- Local models in OpenCode, Claude models in Claude Code (TASK-035). OpenCode shows the model's reasoning while it thinks, starts with a prompt half the size of Claude Code's, and fails fewer tool calls on these models. Claude Code still reaches the local models when needed: `/model` lists the Claude models plus Local Coder and Local Light. OpenCode cannot use the Claude subscription, so it lists only the local models.
- From a Mac: `scripts/mac/ai-remote.sh up` (or `status`, `down`) starts the stack without being at the PC, and `scripts/mac/opencode-local.sh` and `scripts/mac/claude-local.sh` run the clients against it. None of them needs the key. Setup: [docs/remote-client-macos.md](docs/remote-client-macos.md).

**From WSL.** The scripts are Windows PowerShell 5.1 and use Credential Manager, so launch them through `powershell.exe` rather than running anything WSL-side:

```bash
cd /mnt/c/Users/<you>/local-ai
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/ai-up.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/ai-down.ps1
```

`ai-up` and `ai-down` were run this way: `ai-up` returns in about 20 s once the stack is healthy. (Earlier versions of `ai-up` never returned to a WSL caller, because the background processes inherited its output pipe; `Start-Detached` in `scripts/lib/stack.ps1` fixes that, TASK-016.) `claude-local.ps1` was not run from WSL.

`scripts\claude-local.ps1` sets `ANTHROPIC_BASE_URL` and the router key header for that one Claude Code process, and passes `config/claude-settings.json` (picker rows, the window of each local model, per-Read cap, compaction at 80%). It does not set `ANTHROPIC_API_KEY` or `ANTHROPIC_AUTH_TOKEN`: either would replace the subscription login and switch Claude requests to per-token billing. Use `$env:LOCAL_AI_ROUTER` to point it at another router URL.

`scripts\opencode-local.ps1` does the same for OpenCode: it sets `OPENCODE_CONFIG` to `config/opencode.json` and passes the router URL and key as `LOCAL_AI_ROUTER_URL` and `LOCAL_AI_ROUTER_KEY`, for that one process. The config:

- **Models.** Local Coder (the default) and Local Light, with the server's 160K window, 32,000 output tokens, and reasoning effort medium, the same as the server default (`reasoningEffort` per model; the template knows low, medium and xhigh). Auto-update and sharing are off.
- **Permissions.** Edits go through without a prompt. Shell commands ask, except read-only ones and test runs (`git status`, `git diff`, `git log`, `git show`, `ls`, `pwd`, `npm test`, `node --test`, and on the PC, where the shell is PowerShell, `Get-ChildItem`, `Get-Content`, `Get-Item`, `Get-Location`, `Test-Path`, `Resolve-Path`, `Select-String`, `Select-Object`, `Measure-Object` and their usual aliases). Each part of a pipe is checked on its own, and a command with a `{ }` script block always asks. Web fetch is denied. `opencode-local.ps1 --auto` approves the asks for that session; what is denied stays denied.
- **Skills.** OpenCode also loads the skills in `~/.claude/skills`. The eight that need Claude-only tools (built-in-browser, chrome-browser, computer-use, deep-research, docs, google-workspace, import-memory, morning) are denied by name. The file skills (docx, pdf, pptx, xlsx, skill-creator) and the project's own skills still load. A newly synced Claude-only skill shows up until it is added to `permission.skill`.

## Agent sandbox (m-5, in progress)

Each user's agent is OpenClaw in its own Linux container (decision-010, decision-011), built from `sandbox/Dockerfile`: OpenClaw's official image with Chromium, plus Python with openpyxl, python-docx and pypdf from a hash-locked `sandbox/requirements.txt`. One user, the owner, for now.

```powershell
scripts\sandbox.ps1 build            # build local-ai/sandbox (install.ps1 does this when Docker Desktop runs)
scripts\sandbox.ps1 start            # (re)create and start openclaw-owner; the volume keeps logins, files and history
scripts\sandbox.ps1 token            # copy the Control UI token to the clipboard (cleared after 60 s)
scripts\sandbox.ps1 stop             # stop it; reset deletes the volume as well
```

- **Policy is in the image.** `config/openclaw.json5` is baked read-only, so the agent, which runs as the same user, cannot widen its own tools. It allows only the tools the bake-off needs (files, shell, web fetch, browser, images, PDF, asking the user), only the browser plugin and its own skill, and no update checks, telemetry, model catalog downloads or memory plugin (which would wake the model on a schedule). OpenClaw's own sandbox is off: the container is the sandbox.
- **Model.** The router's `local-coder-vision` (TASK-039, option A: 128K shared by two slots, image input), reached at `host.docker.internal:4000`. Until TASK-042 the container gets the router key; TASK-042 replaces it with a credential limited to the local models and isolates the container's network.
- **Access.** The gateway is published on the PC's loopback (`127.0.0.1:18789`) and, by `tailscale serve`, at `https://<pc>.<tailnet>.ts.net:8443` for the Control UI. HTTPS needs Serve enabled on the tailnet once (the script prints the link). The token and the router key reach the container as environment variables from Credential Manager; anyone who can run `docker inspect` on the PC can read them.
- **Startup.** The image's own entrypoint runs `openclaw doctor --fix`, which needs a writable config; the sandbox starts the gateway directly. After changing the OpenClaw version, run doctor once with the config writable.

## Where things live

| What | Where |
|---|---|
| Repo (scripts, configs, backlog) | this folder |
| Binaries (llama.cpp, llama-swap) | `D:\local-ai\bin\` |
| LiteLLM venv | `D:\local-ai\litellm-venv\` |
| Models | `D:\local-ai\models\Qwen3.8-27B-UD-Q6_K.gguf` (local-coder, local-light). The Qwen3.6 files of earlier installs are no longer used and can be deleted |
| Logs | `D:\local-ai\logs\` (`llama-swap.*.log`, `litellm.*.log`, `control.*.log`; `.out` and `.err`), and `control.log`, one line per control request |
| Run state | `D:\local-ai\run\stack.json` (written by `ai-up`, removed by `ai-down`) |
| Router key | Credential Manager, target `local-ai/router-key`; used on the PC only |
| Allowed Tailscale logins | `D:\local-ai\allowed-logins.txt` (one per line) if it exists, otherwise the login the PC is signed in to Tailscale with |
| Control service | `scripts/control-service.py` on 127.0.0.1:4100, started by the scheduled task `local-ai-control` (`install-control.ps1`) |
| Mac client | `~/.config/local-ai/router-url`, written by `scripts/mac/setup-client.sh` |
| Model server config | `config/llama-swap.yaml` |
| Router config | `config/litellm.yaml`, `config/custom_auth.py` |
| Claude Code settings | `config/claude-settings.json` |
| OpenCode settings | `config/opencode.json`; OpenCode's own sessions and logs in `~/.local/share/opencode` |

## Pinned versions

The source of truth is `scripts/versions.psd1`. These passed the acceptance runs.

| Component | Version |
|---|---|
| llama.cpp | b11719, `win-cuda-13.4-x64` plus cudart |
| llama-swap | v265 |
| LiteLLM | 1.106.0 (Python 3.12) |
| uv | 0.13.1 |
| Tailscale | 1.104.1 |
| OpenCode | 1.19.3 (npm `opencode-ai`; the same pin on the Mac) |
| Models | Qwen3.8-27B-UD-Q6_K.gguf (unsloth) |
| NVIDIA driver | 617.42 (not installed by the scripts) |
| Claude Code | 2.1.302 (client, not pinned) |
| Node.js | 22.19.0 (for OpenCode, not installed by the scripts) |
| Docker Desktop | 4.98.0 (agent sandboxes, not installed by the scripts) |
| OpenClaw | 2026.9.36, extended-stable (official image `-browser` with Chromium 1243, pinned by digest in `sandbox/Dockerfile`) |

Changing a pin means changing the version and the hash in `versions.psd1`, rerunning `install.ps1`, and updating the folder names in `config/llama-swap.yaml` and `scripts/ai-up.ps1`, which refer to `llama.cpp-b11719` and `llama-swap-v265`.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `ai-up` says "Not starting: game process running" or "only N MiB of VRAM free" | The game guard (decision-007): a game process, or less than 22,000 MiB free. Close the game, or at the PC use `-Force` knowing the model needs about 30 GB free. The path check only knows the usual game library folders; the free-VRAM check is the hard one. |
| `ai-up` warns "local-coder needs about 30200 MiB and will run slowly" | Between 22,000 and 30,200 MiB of VRAM is free. The stack starts, but part of the model would spill into system memory and slow down. Close GPU-heavy apps before using it. |
| `ai-up` says "partly running or a port is taken" | Run `scripts\ai-down.ps1`, then `ai-up` again. A foreign process on 4000, 8080 or 10001 is reported and left alone; stop it yourself. |
| `ai-up` says "Missing ... Run scripts\install.ps1" or "No router key yet" | Run `install.ps1` or `init-secrets.ps1`. |
| Start fails with a health-check error | Read `D:\local-ai\logs\llama-swap.err.log` or `litellm.err.log`. `ai-up` cleans up after a failed start. |
| Claude Code fails on a large prompt with `exceed_context_size_error` | llama-server must run with `-kvu` next to `--parallel 2`. Without it each of the 2 slots gets only half of the 160K context, 80K, about what Claude Code's own prompt takes (about 67K). It is in `config/llama-swap.yaml`; keep it if you edit the flags. |
| A server context and the Claude Code window disagree | Claude Code must never assume more than the server holds. `CLAUDE_CODE_MAX_CONTEXT_TOKENS` matches the server's `ctx` (163840). Change them together with the macro in `config/llama-swap.yaml`. |
| "Prompt is too long" or a 400 `ContextWindowExceededError` after many parallel Reads | Several large tool results in one turn can overflow the window before compaction runs. `config/claude-settings.json` caps each Read at 8000 tokens and compacts at 80% of the window minus 20K (about 115K). 8 parallel full Reads passed on the earlier entries; 16 (about 128K tokens in one step) end the turn with this error at any percentage (TASK-020), and Claude Code cannot recover from it even when the error is reported as prompt-too-long, because compaction keeps the newest turn (TASK-021). Ask for fewer files per step or line ranges. The percentage can only bring compaction earlier than Claude Code's default, never later. |
| HTTP 401 from the router | On the PC: no key or the wrong key. The key comes from Credential Manager, so after a rotation restart the stack. From another device: its Tailscale login is not on the allowlist (another account, or an `allowed-logins.txt` that does not list it), the request came from a browser (refused on purpose, TASK-031), or the router was started while the PC was signed out of Tailscale (`ai-up` warns about an empty allowlist; restart the stack). A plain `curl` of `/v1/models` without a key on the PC should answer 401: that also proves the router is reachable. |
| HTTP 404 from another device | The URL uses the tailnet IP: since m-3 the router answers only on the MagicDNS name (`http://caps.<tailnet>.ts.net:4000`). Or the stack is down while `/control` is published. |
| `ai-remote.sh` reports an error | Its messages are explained in [docs/remote-client-macos.md](docs/remote-client-macos.md#starting-and-stopping-the-stack-from-the-mac). The PC must be on with you logged in, and `install-control.ps1` must have run once. |
| curl prints `000`, or a timeout, from another device | Nothing answered: the stack is down (`ai-up`, or `ai-remote.sh up` from the Mac), Tailscale is off on one side, or the ACL blocks the device. Check `tailscale status` on both, and that `ai-up` printed a `tailnet http://...:4000` line (it is skipped when Tailscale is signed out). |
| Local model answers slowly the first time | The model is loading (about 12 s) after the 300 s idle unload. `ai-up -Warm` loads `local-coder` up front. |
| Local model shows nothing for a minute or more | It is thinking. Claude Code does not show a local model's reasoning (OpenCode does); long answers (whole files) can think for several minutes even at medium effort. |
| OpenCode stops to ask before a shell command | `config/opencode.json` asks for every shell command except read-only ones and test runs. Approve it, or start with `--auto` for a session without prompts. |
| A Claude model works, a local one fails (or the reverse) | The two routes are separate. Check `D:\local-ai\logs\litellm.err.log` for the failing one; the local side also depends on llama-swap (`http://127.0.0.1:8080/health` on the PC). |

## Security notes

- **Bindings.** The router (4000), the control service (4100), llama-swap (8080) and llama-server (10001) listen on `127.0.0.1` only. Tailnet port 4000, and only that port, is published with `tailscale serve` in HTTP mode: `/` goes to the router (published by `ai-up`, removed by `ai-down`) and `/control` to the control service (published by `install-control.ps1`). `start-litellm.ps1` refuses a non-loopback bind and llama-swap is always started with `-listen 127.0.0.1:8080`. No Windows Firewall rule was added (decision-006, decision-008).
- **Secrets.** The router key is generated in memory by `init-secrets.ps1` and stored in Windows Credential Manager. It is injected into the router process environment at start and into the Claude Code process by `claude-local.ps1`; it is never printed, passed as an argument or written to a file. A scan of the worktree, the git history and the logs found no copy of it (TASK-028). The Claude subscription token is forwarded only to Anthropic: the local deployments are reached through LiteLLM's `openai/` provider with a dummy key, so they never see it.
- **Who gets in.** A remote device is let in by its Tailscale login (decision-008). `tailscale serve` adds `Tailscale-User-Login` to every request it forwards and overwrites one sent by the client; the router and the control service accept only the logins on the allowlist (see "Where things live"; the file stays outside the repo). A request carrying `Origin` or `Sec-Fetch-Site` is refused on this path, so a web page in your browser cannot use your identity (TASK-031). Remote devices hold no key. Programs on the PC can reach the loopback ports and set the identity header themselves; they run as you and could read the key from Credential Manager anyway (accepted in TASK-022).
- **The router key.** One key is the LiteLLM master key and the key `claude-local.ps1` sends on the PC (decision-005), because separate client keys need a database. It also works from any device that reaches the router, so treat it as admin access to the router. If it leaks, rotate it: `scripts\init-secrets.ps1 -Rotate`, then `ai-down` and `ai-up` (the running router keeps the old key until then); no device needs updating ([docs/remote-client-macos.md](docs/remote-client-macos.md#rotating-the-key), TASK-017). `scripts\copy-router-key.ps1` puts the key on the clipboard for 60 s without printing it, for a client that cannot come in by identity; clear Windows clipboard history (Win+V) afterwards if it is on.
- **Refusals.** The router answers 401 to a missing or wrong key and to a login that is not allowed (`config/custom_auth.py`); the control service answers 401 the same way.
- **Control service.** It runs only `ai-up.ps1` and `ai-down.ps1`, without parameters (so no `-Force`), one at a time, and logs every request to `D:\local-ai\logs\control.log`. It holds no GPU memory and never starts the stack by itself.
- **Tailscale ACL.** The tailnet policy has one grant: `autogroup:member` to `autogroup:self` on `tcp:4000`, so only your own devices reach port 4000 of the PC (both routes) and nothing else on it. The default allow-all grant was removed.
- **Tested.** Reachability from a Mac on the tailnet, and the Mac failing after `ai-down`. From a Mac on the LAN with Tailscale off, `nmap -Pn` of ports 4000, 8080 and 10001-10010 on the PC's Wi-Fi address showed all of them `filtered`, and nothing from the stack listens on that address (TASK-014). A key rotation on the PC and the Mac: after it the old key gets 401 on loopback and on the tailnet, the new one 200, and the Mac Keychain holds one item (TASK-017). From the Mac with no key: Claude and local models through the identity, browser-style requests refused (TASK-023, TASK-024, TASK-031), and remote status, up and down, also after a logoff and logon (TASK-025 to TASK-027). After m-3, with the stack down and up, only tailscaled listens on a non-loopback address (the tailnet addresses), tailscale serve publishes only port 4000 with Funnel off, and from WSL only port 4000 answers on the tailnet address and nothing on the Wi-Fi or NordLynx address. From the Mac, `nmap -Pn` of ports 4000, 4100, 8080 and 10001-10010: on the tailnet name only 4000 is open, with the stack up (model loaded) and down; on the Wi-Fi address with Tailscale off, all are filtered (TASK-028).
- **Not tested.** A scan from the public internet (skipped: it would need a router port-forward, the services are loopback-bound, and the PC's NordVPN interface would mask the address). A full `-p-` TCP scan of the PC (too slow against the Windows Firewall, not completed), so other open Windows ports were not enumerated. A device outside the tailnet, or one owned by another user, being refused by the ACL (no such device was available). Remote start of a PC that is asleep: it cannot be woken (no Wake-on-LAN).
- **GPU.** The stack does not set a GPU power limit. The card draws 507-541 W under load; to cap it by hand, `nvidia-smi -pl 460` as administrator (undo with `-pl 575`). The speed cost is unmeasured.
