# local-ai

A local coding model on a Windows PC with an RTX 5090, used from Claude Code through `/model` next to the real Claude models. Started on demand, reachable from your own devices over Tailscale, off when you game.

```
Claude Code (PC or Mac)
  -> router: LiteLLM, 127.0.0.1:4000 (published on the tailnet by tailscale serve), router-key auth
       |- claude models (anthropic/*)  -> api.anthropic.com, on your subscription login
       |- local-coder, local-light     -> llama-swap 127.0.0.1:8080 -> llama-server 127.0.0.1:10001
       |                                  (Qwen3.6 27B Q4_K_M, 128K context, unloads after 5 min idle)
       |- local-coder-q6               -> llama-swap 127.0.0.1:8080 -> llama-server 127.0.0.1:10002
                                          (same model at Q6_K, 160K context, unloads after 5 min idle)
```

`local-light` is an alias of `local-coder` (same process, same weights). `local-coder-q6` is the higher-quality Q6_K quant of the same model with a larger window: about 15-20% slower, and it cannot share VRAM with `local-coder`, so llama-swap unloads one to load the other (TASK-020). The bake-off in the PRD was skipped, so there is no `bench/` folder.

Background and the reasons behind each choice: the PRD (`backlog/docs/doc-0001-PRD.md`), what changed from it (`backlog/docs/doc-002 - PRD-changes-and-implementation-log.md`) and `backlog/decisions/`.

## Requirements

Windows 11, an NVIDIA GPU with about 24 GB of free VRAM for `local-coder` and about 28.5 GB for `local-coder-q6` (with their caches they use 21.4 GB and 27.7 GB; built and measured on a 32 GB RTX 5090), a current NVIDIA driver (CUDA 12.8 or newer, compute capability 12.0), PowerShell 5.1, and a Claude subscription logged in to Claude Code. `install.ps1` installs everything else.

## Install (once)

```powershell
scripts\install.ps1            # binaries, LiteLLM venv, both models (16 GB and 21 GB), all hash-verified
scripts\install.ps1 -CheckOnly # report what is present or missing, change nothing (exit 2 if work is needed)
scripts\init-secrets.ps1       # create the router key in Windows Credential Manager
```

`install.ps1` is safe to rerun. It installs missing `uv` and Tailscale with winget at the pinned versions (Tailscale needs a one-time sign-in afterwards) and never installs the NVIDIA driver. Everything lands in `D:\local-ai` (override with `-Root` or `LOCAL_AI_ROOT`), outside the repo.

## Daily use

```powershell
scripts\ai-up.ps1          # start: llama-swap + router, tailnet publishing; healthy in about 15-20 s
scripts\claude-local.ps1   # Claude Code against the local router; all arguments go to claude
scripts\ai-down.ps1        # stop everything and free the GPU (VRAM goes back to idle in a few seconds)
```

- `ai-up -Warm` loads `local-coder` immediately; otherwise the first local request loads its model (about 10 s, 18 s for the Q6_K).
- Switching between Local Coder and Local Coder Q6 reloads the model: the first answer after a switch takes about 12-13 s. Local Light shares Local Coder's process, so it switches instantly. Two sessions on different local models make llama-swap swap on every request.
- `ai-up -NoTailnet` keeps the router on loopback only. `ai-up -Force` skips the game guard.
- Nothing starts at boot. The model unloads by itself after 300 s without requests; `ai-down` also stops the processes.
- In Claude Code, `/model` lists the Claude models plus Local Coder, Local Light and Local Coder Q6.
- From a Mac, see [docs/remote-client-macos.md](docs/remote-client-macos.md).

**From WSL.** The scripts are Windows PowerShell 5.1 and use Credential Manager, so launch them through `powershell.exe` rather than running anything WSL-side:

```bash
cd /mnt/c/Users/<you>/local-ai
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/ai-up.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/ai-down.ps1
```

`ai-up` and `ai-down` were run this way: `ai-up` returns in about 20 s once the stack is healthy. (Earlier versions of `ai-up` never returned to a WSL caller, because the background processes inherited its output pipe; `Start-Detached` in `scripts/lib/stack.ps1` fixes that, TASK-016.) `claude-local.ps1` was not run from WSL.

`scripts\claude-local.ps1` sets `ANTHROPIC_BASE_URL` and the router key header for that one Claude Code process, and passes `config/claude-settings.json` (picker rows, the window of each local model, per-Read cap, compaction at 80%). It does not set `ANTHROPIC_API_KEY` or `ANTHROPIC_AUTH_TOKEN`: either would replace the subscription login and switch Claude requests to per-token billing. Use `$env:LOCAL_AI_ROUTER` to point it at another router URL.

## Where things live

| What | Where |
|---|---|
| Repo (scripts, configs, backlog) | this folder |
| Binaries (llama.cpp, llama-swap) | `D:\local-ai\bin\` |
| LiteLLM venv | `D:\local-ai\litellm-venv\` |
| Models | `D:\local-ai\models\Qwen3.6-27B-Q4_K_M.gguf` (local-coder, local-light), `Qwen3.6-27B-Q6_K.gguf` (local-coder-q6) |
| Logs | `D:\local-ai\logs\` (`llama-swap.*.log`, `litellm.*.log`; `.out` and `.err`) |
| Run state | `D:\local-ai\run\stack.json` (written by `ai-up`, removed by `ai-down`) |
| Router key | Credential Manager, target `local-ai/router-key` (Keychain item of the same name on the Mac) |
| Model server config | `config/llama-swap.yaml` |
| Router config | `config/litellm.yaml`, `config/custom_auth.py` |
| Claude Code settings | `config/claude-settings.json` |

## Pinned versions

The source of truth is `scripts/versions.psd1`. These passed the acceptance runs.

| Component | Version |
|---|---|
| llama.cpp | b11719, `win-cuda-13.4-x64` plus cudart |
| llama-swap | v265 |
| LiteLLM | 1.106.0 (Python 3.12) |
| uv | 0.13.1 |
| Tailscale | 1.104.1 |
| Models | Qwen3.6-27B-Q4_K_M.gguf and Qwen3.6-27B-Q6_K.gguf (unsloth) |
| NVIDIA driver | 617.42 (not installed by the scripts) |
| Claude Code | 2.1.302 (client, not pinned) |

Changing a pin means changing the version and the hash in `versions.psd1`, rerunning `install.ps1`, and updating the folder names in `config/llama-swap.yaml` and `scripts/ai-up.ps1`, which refer to `llama.cpp-b11719` and `llama-swap-v265`.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `ai-up` says "Not starting: game process running" or "only N MiB of VRAM free" | The game guard (decision-007). Close the game, or use `-Force` knowing the model needs about 22 GB free. The path check only knows the usual game library folders; the free-VRAM check is the hard one. |
| `ai-up` warns "enough for local-coder, not for local-coder-q6" | Less than 28,500 MiB of VRAM is free. The stack starts; Local Coder works, but Local Coder Q6 would spill into system memory and slow down. Close GPU-heavy apps before picking it. |
| `ai-up` says "partly running or a port is taken" | Run `scripts\ai-down.ps1`, then `ai-up` again. A foreign process on 4000, 8080, 10001 or 10002 is reported and left alone; stop it yourself. |
| `ai-up` says "Missing ... Run scripts\install.ps1" or "No router key yet" | Run `install.ps1` or `init-secrets.ps1`. |
| Start fails with a health-check error | Read `D:\local-ai\logs\llama-swap.err.log` or `litellm.err.log`. `ai-up` cleans up after a failed start. |
| Claude Code fails on a large prompt with `exceed_context_size_error` | llama-server must run with `-kvu` next to `--parallel 2`. Without it each of the 2 slots gets only half of the 128K context, 64K, less than Claude Code's own prompt (about 67K). It is in `config/llama-swap.yaml`; keep it if you edit the flags. |
| A server context and the Claude Code window disagree | Claude Code must never assume more than the server holds. `CLAUDE_CODE_MAX_CONTEXT_TOKENS` (one value for every local model) matches the largest server, `ctx-q6` (163840); `modelSettings.local-coder` and `local-light` set `autoCompactWindow` to `ctx` (131072). Change them together with the macros in `config/llama-swap.yaml`. |
| "Prompt is too long" or a 400 `ContextWindowExceededError` after many parallel Reads | Several large tool results in one turn can overflow the window before compaction runs. `config/claude-settings.json` caps each Read at 8000 tokens and compacts at 80% of the window minus 20K (local-coder at about 89K, local-coder-q6 at about 115K). 8 parallel full Reads pass on both; 16 (about 128K tokens in one step) end the turn with this error at any percentage (TASK-020). Ask for fewer files per step or line ranges. The percentage can only bring compaction earlier than Claude Code's default, never later. |
| HTTP 401 from the router | No key or the wrong key. On the PC the key comes from Credential Manager, so after a rotation restart `ai-up`; on a Mac rerun `setup-client.sh`. A plain `curl` of `/v1/models` without a key should answer 401: that also proves the router is reachable. |
| curl prints `000`, or a timeout, from another device | Nothing answered: the stack is down (`ai-up`), Tailscale is off on one side, or the ACL blocks the device. Check `tailscale status` on both, and that `ai-up` printed a `tailnet http://...:4000` line (it is skipped when Tailscale is signed out). |
| Local model answers slowly the first time | The model is loading (about 10 s, 18 s for the Q6_K) after the 300 s idle unload or a switch between Local Coder and Local Coder Q6. `ai-up -Warm` loads `local-coder` up front. |
| A Claude model works, a local one fails (or the reverse) | The two routes are separate. Check `D:\local-ai\logs\litellm.err.log` for the failing one; the local side also depends on llama-swap (`http://127.0.0.1:8080/health` on the PC). |

## Security notes

- **Bindings.** The router (4000), llama-swap (8080) and llama-server (10001 for local-coder, 10002 for local-coder-q6) listen on `127.0.0.1` only. `ai-up` publishes port 4000, and only 4000, on the tailnet with `tailscale serve`, and `ai-down` unpublishes it. `start-litellm.ps1` refuses a non-loopback bind and llama-swap is always started with `-listen 127.0.0.1:8080`. No Windows Firewall rule was added (decision-006).
- **Secrets.** The router key is generated in memory by `init-secrets.ps1` and stored in Windows Credential Manager. It is injected into the router process environment at start and into the Claude Code process by `claude-local.ps1`; it is never printed, passed as an argument or written to a file. A scan of the worktree found no copy of it. The Claude subscription token is forwarded only to Anthropic: the local deployments are reached through LiteLLM's `openai/` provider with a dummy key, so they never see it.
- **One shared key.** The same key is the LiteLLM master key and the key every client sends (decision-005), because separate client keys need a database. Anyone holding it can use the router; if it leaks, rotate it: `scripts\init-secrets.ps1 -Rotate`, restart with `ai-down` and `ai-up`, then rerun `scripts/mac/setup-client.sh` on every device (see [docs/remote-client-macos.md](docs/remote-client-macos.md)). `scripts\copy-router-key.ps1` puts the key on the clipboard for 60 s without printing it; clear Windows clipboard history (Win+V) afterwards if it is on.
- **Wrong keys.** The router answers 401 to a missing or wrong key (`config/custom_auth.py`).
- **Tailscale ACL.** The tailnet policy has one grant: `autogroup:member` to `autogroup:self` on `tcp:4000`, so only your own devices reach port 4000 of the PC and nothing else on it. The default allow-all grant was removed.
- **Tested.** Reachability from a Mac on the tailnet, and the Mac failing after `ai-down`. From a Mac on the LAN with Tailscale off, `nmap -Pn` of ports 4000, 8080 and 10001-10010 on the PC's Wi-Fi address showed all of them `filtered`, and nothing from the stack listens on that address (TASK-014).
- **Not tested.** A scan from the public internet (skipped: it would need a router port-forward, the services are loopback-bound, and the PC's NordVPN interface would mask the address). A full `-p-` TCP scan of the PC (too slow against the Windows Firewall, not completed), so other open Windows ports were not enumerated. A device outside the tailnet, or one owned by another user, being refused by the ACL (no such device was available). A router key rotation run on both machines (TASK-017).
- **GPU.** The stack does not set a GPU power limit. The card draws 507-541 W under load; to cap it by hand, `nvidia-smi -pl 460` as administrator (undo with `-pl 575`). The speed cost is unmeasured.
