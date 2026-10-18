# PRD: Local AI Coding Stack (Claude Code + local models)

Status: Draft v1, 2026-10-18. Owner: single user (developer). Implementation target: a new VS Code project driven by Claude Code.

## 1. Goal

Run local LLMs on the user's PC and use them from the Claude Code harness, selectable through `/model` alongside real Anthropic models. Use them to offload tokens for light coding, code reviews and text tasks (PR descriptions, Jira tickets). Reachable from outside the home network. Active only when the user starts it.

### Non-goals
- Matching Opus-level quality (not possible on 32 GB VRAM).
- Multi-user serving, team sharing, CI access.
- Concurrent agents / high-throughput serving.
- Always-on operation.

## 2. Environment

| Item | Value |
|---|---|
| Motherboard | ASUS X670E-A |
| CPU | Ryzen 7 7800X3D |
| RAM | 32 GB DDR5-6000 CL30 (no upgrade planned) |
| GPU | RTX 5090 32 GB (Zotac Solid), Blackwell |
| Storage | 3x 1 TB NVMe (WD SN850X, Samsung 980 Pro, Sabrent Rocket 4). Models go on the SN850X. |
| OS | Windows 11 Pro |
| Languages | TypeScript (primary), Rust (increasingly) |
| Same machine is used for gaming | GPU must be free when not coding |

Constraints: VRAM is the binding limit. 32 GB RAM means no MoE spill-over into system RAM, so models must fit in VRAM including KV cache. The GPU is shared with the desktop and games.

## 3. Requirements

### Functional
- F1. Claude Code (on the PC and on remote devices) talks to one endpoint and shows one `/model` list containing real Claude models and local models.
- F2. Local `local-coder` model for coding and agentic edits. Local `local-light` alias for reviews and text (initially the same model).
- F3. Remote access from the user's own devices over Tailscale only.
- F4. Single command to start the stack and one to stop it. No auto-start at boot.
- F5. Idle auto-unload of model weights from VRAM.
- F6. Secrets are never stored in plaintext in the repo or on disk.

### Non-functional
- N1. Coder throughput of at least about 40 tok/s generation at 64K context, with usable prompt-processing speed.
- N2. No ports exposed to LAN or the public internet. Router reachable via tailnet and localhost only.
- N3. Stack fully stoppable, freeing all VRAM within seconds.

## 4. Architecture

```
Client (PC / laptop / phone) -- Tailscale --> PC
  Router (LiteLLM) :4000   [local key auth]
    |- claude-* models  --> api.anthropic.com (pass-through)
    |- local-coder      -+
    |- local-light      -+--> llama-swap :8080 --> llama.cpp llama-server (CUDA)
```

Claude Code is configured with `ANTHROPIC_BASE_URL` pointing at the router, `ANTHROPIC_CUSTOM_HEADERS="x-litellm-api-key: Bearer <local key>"` for router auth, `CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1`, and no `ANTHROPIC_AUTH_TOKEN` (so the subscription login is kept and forwarded).

## 5. Decisions

| Topic | Decision | Rationale |
|---|---|---|
| OS | Windows native | Single-stream use; llama.cpp is fastest and simplest here. No vLLM, so WSL2 adds nothing. |
| Inference | llama.cpp `llama-server`, CUDA 12.8+ build | Native Anthropic-style `/v1/messages` (to verify), full control of quant, KV cache, flash attention. |
| Model management | llama-swap | On-demand load, `ttl` idle unload, multiple model configs. |
| Router | LiteLLM (venv / `uv`) | Needed for the single `/model` list: mixes Anthropic pass-through with local models. Fallback: separate `claude-local` profile. |
| Remote access | Tailscale | No open ports, ACLs, works on phone/laptop. Bind to the tailnet interface only. |
| Lifecycle | `ai-up.ps1` / `ai-down.ps1` | User wants it off during gaming. |
| Secrets | 1Password CLI (`op run`) or Windows Credential Manager | Injected into the process environment at start. Real Anthropic key lives only in the router process. Clients use a local key. |

## 6. Models

Candidates (from web sources of mixed quality; benchmark before trusting):

- `local-coder`: **Qwen3.6 27B** dense, Q4_K_M (~17 GB), 64K context, q8 KV cache. Primary candidate.
- Challengers: Qwen3.6 35B-A3B (MoE), Laguna XS 2.1, Gemma 4 27B, Nemotron 3.5 30B-A3B, Qwen3-Coder 30B.
- `local-light`: initially an alias to the coder. Add a small 8-14B model only if the coder is too slow for text tasks. It would swap in and out, not stay resident.

### Bake-off (acceptance for model choice)
10-15 tasks from the user's own repos: TypeScript refactors, Rust borrow-checker / compile-error fixes, a code review of a real diff, a PR description, a Jira ticket. Metrics: pass/fail against a rubric, tok/s generation, prompt-processing speed, tool-call failure rate inside Claude Code. Output: results table, pick winner.

## 7. Resolved questions (researched 2026-10-18)

Every former open risk now has a decision. Items marked **Spike** are confirmed by a test in phase 1 with a predefined fallback, so nothing remains undecided.

| # | Question | Resolution | Source |
|---|---|---|---|
| R1 | Can subscription OAuth work through a router that also serves local models? | Yes for the Claude side. LiteLLM forwards the client's `Authorization: Bearer sk-ant-oat...` token to `anthropic/*` deployments (v1.81.14+). The router's own auth uses a *separate* header: `x-litellm-api-key`, sent via `ANTHROPIC_CUSTOM_HEADERS`. **Do not set `ANTHROPIC_AUTH_TOKEN` or `ANTHROPIC_API_KEY`**: a gateway credential variable replaces the subscription login and switches to per-token API billing. Local deployments use their own configured credentials and never receive the OAuth token. LiteLLM's docs don't show a mixed config explicitly, so **Spike S1** tests it. Fallback F1: separate `claude-local` profile with `ANTHROPIC_BASE_URL` pointed at the router and no OAuth. | LiteLLM Claude Max tutorial; Claude Code LLM gateway docs |
| R2 | How do local models appear in `/model`? | Solved by supported mechanisms: `CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1` fills the picker from the gateway's `/v1/models`; `ANTHROPIC_CUSTOM_MODEL_OPTION` adds one entry; `modelOverrides` / `modelPicker` in `settings.json` control labels and what each entry behaves as. Use discovery first, `modelPicker` for friendly names (`local-coder`, `local-light`). Requires Claude Code v2.1.257+ for session-only switching (`s`). **Spike S2** checks that the context window Claude Code assumes for local models matches the server's (64K) and that auto-compaction triggers correctly. Fallback F2: `ANTHROPIC_CUSTOM_MODEL_OPTION` plus an explicit compaction threshold setting. | Claude Code model-config docs |
| R3 | Does llama.cpp speak the Anthropic API? | Yes. `llama-server` supports `POST /v1/messages` with streaming, `/v1/messages/count_tokens`, tool use, vision and extended thinking, by converting to its OpenAI path. Launch with `--jinja` (needed for tool-call templates). Because LiteLLM sits in front, it can also talk to llama-swap over the OpenAI route if the Anthropic route misbehaves with a specific model (fallback F3). | llama.cpp PR 17570; Hugging Face ggml-org blog |
| R4 | Are ~27B models reliable at tool calls in Claude Code's large prompts? | Cannot be decided by research. It becomes a **measured acceptance gate** in the bake-off: tool-call failure rate under 5% across the task set and at least 70% task pass. If the winner misses the gate: first try another model/quant, then prompt/flag tuning. **Harness decision (2026-10-18): Claude Code only.** A lighter harness (OpenCode) was considered and deliberately deferred, not adopted; see open point O1. Note Anthropic does not support non-Claude models through gateways, so expect to own this compatibility. | Claude Code LLM gateway docs |
| R5 | Network exposure | Resolved by design: LiteLLM binds to the Tailscale interface address and loopback only; llama-swap and llama-server bind to loopback only; Windows Firewall inbound rule scoped to the `Tailscale` interface; Tailscale ACL limits access to the user's own devices. Verified by acceptance test A4 (port scan from LAN). | n/a |
| R6 | Blackwell (RTX 5090) support | RTX 50-series needs CUDA 12.8+ (sm_120). Use the official llama.cpp Windows CUDA 12.x release or build with `-DCMAKE_CUDA_ARCHITECTURES=120`, with a current NVIDIA driver. Confirmed by smoke test **S3** (model loads fully on GPU, `nvidia-smi` shows ~all layers offloaded, tok/s meets N1). | NVIDIA / llama.cpp docs |
| R7 | LiteLLM weight and security record | Pin a version, run in a venv with SQLite or no DB (single user, no budgets needed), bind to tailnet only, keep the master key in the secret store, and enable only the routes used. Revisit alternatives only if the spike fails. | n/a |

### Phase-1 spike checklist (pass/fail, with fallback)
- S1: One Claude Code session on the subscription OAuth login, pointed at the router, can call both a Claude model and `local-coder`. Fail leads to F1.
- S2: `/model` lists both families; local context window and compaction behave. Fail leads to F2.
- S3: llama.cpp loads Qwen3.6 27B Q4 fully on GPU on the 5090 and hits N1. Fail leads to trying another quant/build, then another model.
- S4: A multi-step tool-use task completes against the local model through the router. Fail leads to F3 (OpenAI route), then another model, then open point O1.

## 8. Deliverables

1. `scripts/install.ps1`: checks drivers/CUDA, downloads llama.cpp CUDA build and llama-swap, creates LiteLLM venv, verifies Tailscale.
2. `config/llama-swap.yaml`: model definitions, flags, `ttl`.
3. `config/litellm.yaml`: model list, pass-through, local key auth.
4. `scripts/ai-up.ps1` / `scripts/ai-down.ps1`: start/stop, secret injection, health checks, optional refusal if a game is running, optional GPU power limit (`nvidia-smi -pl`, about 80%).
5. Client config: Claude Code `settings.json` / env for PC and remote devices; docs for `claude-local` fallback.
6. `bench/`: bake-off harness and results table.
7. `README.md`: usage, troubleshooting, security notes.

## 9. Implementation phases

1. **Spike (verify risks 1-3, 6):** llama.cpp + one model, hit it from Claude Code directly via `ANTHROPIC_BASE_URL`. Then add LiteLLM pass-through and check the `/model` list.
2. **Infra:** llama-swap, LiteLLM, scripts, secrets, Tailscale binding.
3. **Bake-off:** pick `local-coder` (and decide on `local-light`).
4. **Remote:** configure laptop/phone, test from outside the network.
5. **Hardening and docs.**

## 10. Acceptance criteria

- `ai-up` brings the stack healthy in under 2 minutes. `ai-down` leaves VRAM near idle.
- From the PC and a remote device on Tailscale, `/model` lists real Claude models and the local models. Selecting each works.
- A multi-step edit task completes with the local coder in Claude Code, with tool calls succeeding.
- A4: Nothing is reachable from LAN / public internet (port scan check).
- No secrets present in the repo or in plaintext config.
- Model is unloaded after the idle `ttl`.

## 11. Future / out of scope for now
- 64 GB+ RAM upgrade to enable larger MoE models with CPU offload.
- Embeddings / codebase RAG model.
- Request logging / observability (Langfuse, Open WebUI).
- Cloudflare Tunnel + Access if others ever need access.

## 12. Open points (deliberately deferred)

No decision in sections 1-11 is pending. These are known unknowns to handle when their phase arrives.

| ID | Open point | When | Trigger / how to resolve |
|---|---|---|---|
| O1 | Alternative harness for local models (OpenCode, Aider). Decision today: stay on Claude Code. | Phase 3 (bake-off), only if S4 fails or the tool-call gate (under 5% failures, at least 70% pass) is missed | Re-run the same task set in OpenCode against llama-swap directly. Adopt for local models only on a clear margin (about 15+ points pass rate or half the tool failures). Also check whether subscription logins work in third-party harnesses. |
| O2 | Final `local-coder` model | Phase 3 | Bake-off winner among Qwen3.6 27B and challengers (section 6). Model names come from low-quality web sources, so re-check availability and licenses at download time. |
| O3 | Whether `local-light` needs its own small model | Phase 3 | Only if the coder is too slow or heavy for PR/Jira text. Otherwise keep it an alias. |
| O4 | Local context size (64K assumed) | S2 / phase 3 | Tune against VRAM headroom and quality; q8 KV cache assumed. |
| O5 | Exact `modelPicker` labels and whether discovery or custom entries win | S2 | Pick whichever gives the cleanest list on the installed Claude Code version. |
| O6 | LiteLLM mixed-config details (wildcard `anthropic/*` plus local entries, header handling) | S1 | Docs don't show a combined example; resolve by test, fallback F1. |
| O7 | Secret store choice: 1Password CLI vs Windows Credential Manager | Phase 2 | Use whichever the user already has installed; both meet F6. |
| O8 | Game-detection guard in `ai-up` and GPU power limit value | Phase 2 | Optional niceties; decide when writing scripts. |
| O9 | RAM upgrade to 64 GB+ | When budget allows | Unlocks larger MoE models with CPU offload; reopen model selection then. |
| O10 | Pinned versions (llama.cpp build, llama-swap, LiteLLM, Claude Code minimum) | Phase 1-2 | Record the versions that pass the spike in the README. |

