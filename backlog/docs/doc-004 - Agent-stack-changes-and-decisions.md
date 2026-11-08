---
id: doc-004
title: Agent stack changes and decisions
type: other
created_date: '2026-11-08 17:38'
updated_date: '2026-11-08 20:09'
---
# Agent stack changes and decisions

The counterpart of doc-002 for the agent PRD (doc-003). It holds the full text of the agent stack's decision records, which the Backlog CLI creates with only a title and a status, and records later deviations from doc-003 and where the evidence lives.

## decision-010: OpenClaw as the agent, one gateway per user

**Context.** doc-003 section 7 planned a spike among 2-3 candidates. The user chose OpenClaw without a spike (2026-11-08). The other candidates looked at:

- AgenticOS: multi-user with Google sign-in, approvals, sandboxes and schedules, but young, and built as a shared team workspace with an organization audit log.
- LibreChat plus MCP tools: the most control, the most work.
- Suna/Kortix: needs cloud services (Supabase, Daytona, Composio). Ruled out.
- Hermes Agent: its dashboard has no multi-user sign-in. Ruled out.

OpenClaw's own security model: "A gateway is one trust domain". It is "not a hostile multi-tenant security boundary for mutually adversarial users", and for users who must be isolated it says to "run one gateway per tenant instead, ideally on separate OS users or hosts". Its multiplayer mode shares sessions and tool authority inside one team; its roles are "collaboration guardrails inside the boundary, not isolation between adversaries".

**Decision.** Each user gets their own OpenClaw gateway, running inside their own sandbox container (decision-011). Users never share a gateway, and multiplayer mode is not used. OpenClaw's scheduled jobs (`automations`/`cron`) are the scheduler (AF6). Its browser tool drives a Chromium in the same container. OpenClaw's own tool sandbox stays off: the container is the sandbox, and nested Docker is not used. The OpenClaw version is pinned like every other component, and plugins and skills come only from an allowlist pinned in the repo (AF10).

**Consequences.**

- Isolation between users (AN4) comes from containers, not from OpenClaw.
- Connection to the router: OpenClaw reaches it as an OpenAI-compatible custom provider (`api: "openai-completions"`) with `input: ["text", "image"]`, and `contextWindow` and `maxTokens` set to the slot's real window.
  - Its docs warn that a model that answers short prompts can still fail agent turns, and that tool calls emitted as plain text are not executed. The bake-off (doc-003 section 8) has to show the local model passes in OpenClaw itself.
- Its docs advise narrow agents and compaction on with local models, against prompt injection. The tool allowlist per agent (`tools.allow` / `tools.deny`) is the main lever. Unused tools (`image_generate`, `x_search` and the like) are denied.
- Open, to settle in implementation:
  - Approvals: OpenClaw documents approvals for host commands (exec approvals) and `ask_user` for user decisions. A hard gate for sending, buying, submitting, deleting and sharing (AF5, AN8) is not documented (doc-003 P9).
  - MCP: its docs do not mention MCP, which decides how the Google tools are added (OpenClaw plugin or skill, or an MCP server such as `workspace-mcp`).
  - Google Chat is named as a channel plugin, with no documentation page. Notifications (D2) depend on it.
- A per-user gateway costs RAM per sandbox (Node plus Chromium). Measure it against the sandbox cap (AF3).

## decision-011: Sandboxes are Docker Desktop Linux containers, one per user; hosts stay Windows 11

**Context.** AF3 and AN4 need a persistent, isolated environment per user, with a browser, files and a shell, on a Windows 11 host. The company qualifies for free Docker Desktop (under 250 employees and under $10M revenue; user, 2026-11-08). The user prefers OrbStack on macOS, but the hosts are Windows 11 PCs (doc-003 section 2), and OrbStack exists only for macOS. A Mac host is not a goal.

**Decision.** Docker Desktop with the WSL2 backend on every install. Each user's sandbox is one Linux container from one image built by the repo: pinned OpenClaw, Chromium and the tools the tasks need (Python, office file libraries). Each container gets a named volume for its home folder (browser profile, files, OpenClaw state). Resetting a sandbox deletes the volume. Docker Desktop's version is pinned in `versions.psd1` with the others.

**Consequences.**

- A new prerequisite for the install: WSL2 and Docker Desktop. The install checks them, like it checks the NVIDIA driver; whether it installs Docker Desktop itself is decided in implementation.
- Network rules for the containers:
  - They need the internet (web tasks) and the router, and nothing else on the host or the LAN.
  - Docker Desktop exposes the host as `host.docker.internal`, so blocking the rest (the control service, llama-swap, the admin endpoints, LAN devices) needs explicit rules: an internal network plus an egress proxy, or firewall rules. To be designed and tested (A3).
- The router credential for a sandbox:
  - Anything inside a container can be read by the agent, so a sandbox gets its own router credential, not the router key.
  - That credential reaches only the local models: no Claude models, since everything must stay local and they cost money.
- Encryption at rest (AN7): the containers' data lives in Docker Desktop's WSL2 virtual disk. Covered by BitLocker on the drive, or by encryption inside the volume; to be decided in implementation.
- RAM: Docker Desktop's WSL2 VM takes a fixed share of host RAM. The sandbox cap is computed from what is left after the model server and the desktop.
- Sleeping sandboxes are stopped containers. Their volumes stay, so starting one again keeps logins and files.

## decision-012: Front door: Caddy, oauth2-proxy for Google sign-in, and a small portal of ours

**Context.** Several things need one entry point:

- Google sign-in (AF2, D1), with the domain plus listed extra addresses;
- sending each user to their own OpenClaw gateway (decision-010);
- starting and sleeping sandboxes under the RAM cap (AF3);
- HTTPS on the tailnet and, as an option, on the office network under a company subdomain (AN5, D3, D4).

OpenClaw accepts a verified identity from a trusted proxy in front of it. With a shared token instead, every user would appear as one owner.

**Decision.**

- **Caddy** terminates HTTPS:
  - On the tailnet, it sits behind `tailscale serve`, which provides the `ts.net` certificate.
  - On the office network (when the install enables it), it binds the LAN address with a Let's Encrypt certificate obtained through DNS validation, so it needs a Caddy build with the company's DNS provider module.
- **oauth2-proxy** does the Google sign-in (OIDC) and checks the allowlist (domain plus extra addresses), then passes the verified email to the portal.
- **The portal** is a small TypeScript service of ours (decision-014). It maps the email to that user's container, creates the container on first sign-in, starts it when needed, stops it when idle, applies the cap and queues users over it, shows a "starting your sandbox" page while it waits, and proxies the user's traffic (HTTP and WebSocket) to their gateway with the identity header OpenClaw trusts.
- Each gateway listens only on the internal Docker network and is reachable only through the portal.

**Consequences.**

- Three new components to pin and install: Caddy (custom build with the DNS module), oauth2-proxy and the portal.
- The Google OAuth client (D1) is configured once per install, in oauth2-proxy. The Gmail and Drive scopes for the agent's Google tools may need a separate consent from inside the sandbox, depending on how the Google tools are added (decision-010, open).
- The router (port 4000) and the control service stay where they are today: loopback, plus the tailnet for the router. Only the web page goes on the office network.
- The portal is the one piece of security-sensitive code we write. It handles no passwords or Google tokens, but it decides which container a signed-in user reaches, so it needs tests for that mapping (A3).
- Who may sign in is set per install, in one config (the allowlist), read by oauth2-proxy.

## decision-013: Model serving stays llama.cpp, llama-swap and LiteLLM; it adds the vision projector, and the install picks the model by VRAM

**Context.** doc-003 section 6 needs a vision-capable model that is also good at coding, Italian and tool calls, shared by the coding stack and the agents. It must fit 24 GB (office) and 32 GB (home). Qwen3.8 27B reads images in llama.cpp with its projector (`--mmproj`, about 0.9 GB). Today's serving stack (decision-002, decision-009) already serves it to both Claude Code and OpenCode.

**Decision.** Keep llama.cpp server behind llama-swap, behind the LiteLLM router. The model entries get the vision projector. `versions.psd1` holds a tested model list, each entry with the VRAM it needs and the slots and window it runs with. The install picks the best entry that fits the detected GPU and writes it into the llama-swap config. Idle unload stays (D5). The first candidate for both sizes is Qwen3.8 27B: UD-Q6_K with MTP at 32 GB if the projector fits, and a Q4-class quant at 24 GB. The bake-off fills the list.

**Consequences.**

- decision-009 (one fixed model) becomes one entry of the list. Its 2 slots at 160K and 29.4 GB leave no room for the projector on the idle home desktop (about 30.4 GB free), so the 32 GB entry changes: fewer slots, a shorter window, or a smaller quant. Measured in the bake-off.
- Slots: several agents and coding sessions share the model's slots. Agent tasks probably need less context than 160K per slot, so the list sets slots and window per entry (doc-003 P8).
- ai-up's VRAM thresholds come from the chosen entry instead of fixed numbers. The game guard goes (doc-003 section 5); decision-007 is superseded when that is implemented.
- Claude Code and OpenCode keep their settings, with the window and model names generated from the chosen entry.

## decision-014: New code in TypeScript on Node

**Context.** The repo's scripts are PowerShell 5.1 (Windows) and bash (Mac client); the router's custom auth is Python. The agent stack needs new long-running code: first the portal (decision-012), later probably a notification bridge and the sandbox image build. TypeScript is the user's main language. OpenClaw runs on Node, and Node is already a prerequisite for OpenCode.

**Decision.** New services and tools are written in TypeScript on Node, with the Node version pinned with the others. PowerShell stays for install and start/stop scripts on Windows, and Python stays for the LiteLLM custom auth.

**Consequences.**

- The repo gets a Node workspace (package.json, lockfile, tests) for the portal and later services.
- On the host, the portal runs either as a Windows process managed like the router, or as a container next to the sandboxes; decided in implementation. As a container it needs access to the Docker API to manage the sandboxes, which must not be reachable from the sandboxes themselves.

## Open decisions

Not decided yet; each one gets a decision record when it is settled.

| Topic | Depends on | Notes |
|---|---|---|
| Where confirmations are enforced (AF5, AN8; doc-003 P9) | Trying OpenClaw's exec approvals and `ask_user` | A hard gate the model cannot skip, at least for Google actions (send, delete, share) and form submits |
| How the Google tools are added | Whether OpenClaw takes MCP servers; `workspace-mcp` (multi-user OAuth 2.1) as the candidate | Also decides whether users consent twice (sign-in and tools) |
| Notifications (D2) | OpenClaw's Google Chat channel plugin; Web Push from the portal for non-domain users | doc-003 P5 |
| Sandbox network isolation | decision-011 | Internal network plus egress proxy, or firewall rules |
| Encryption at rest | decision-011 | BitLocker, or encrypted volumes |

## Vision projector on the 32 GB card (TASK-039, m-5)

**Setup.**

- **Projector.** unsloth `mmproj-F16.gguf` for Qwen3.8 27B, saved as `D:\local-ai\models\Qwen3.8-27B-mmproj-F16.gguf` (927,607,488 bytes, SHA-256 `cbb841a9ee0636b2ec172f5bb8df2ea8dfeb01e90fe7c6126581d662a0b4e43e`), pinned in `scripts\versions.psd1` so install.ps1 fetches it.
- **Smaller quant.** unsloth `Qwen3.8-27B-UD-Q5_K_XL.gguf` (20,876,938,144 bytes, SHA-256 `8601193d3d5760c37fb8ce1b43afebc69df5fb24e1fbc5a547c32e2200305276`). Not pinned: it stays on this PC's disk only, for fallback B.
- **Trial entry.** `local-coder-vision` in `config/llama-swap.yaml` and `config/litellm.yaml`, on port 10002, measured with today's local-coder flags plus `--mmproj` and now set to option A below. Not in the Claude Code or OpenCode settings; local-coder is unchanged.
- **Measurements.** Against a bench llama-swap on 127.0.0.1:8081 (`D:\local-ai\scratch\vision`, with the stack down), using TASK-020's script plus two image requests. Every setup runs MTP draft 3 with q8_0 caches and `-kvu`. The card has 32,607 MiB; the idle desktop held 1.1-1.4 GB during the runs (1.6 GB in TASK-033).

**MTP with the projector.** b11719 keeps MTP speculative decoding on when `--mmproj` is loaded, for text requests and for requests with an image (acceptance 0.62-0.81). This was the first thing to check: if the build had switched MTP off, every option would have been about half as fast.

**Reading images.** 13 questions with known answers, in Italian and English, over three images built for the test:

- a 1280x800 supplier web page (menu, price table, quote form with two buttons);
- a 1240x1754 invoice degraded to look scanned (grayscale, 1.5° rotation, noise, blur, JPEG quality 55);
- a 1280x800 page of 10 px terms in three columns.

The questions went through llama-swap and the router alike; the router passes images to the openai/ route unchanged. With the default image size: 12/13 right.

- **Right:** the menu, the prices and delivery times, the invoice number, date, total, VAT number and IBAN, the hours sum and the VAT check, two of the three small-text facts.
- **Click positions** come back in the image's own pixels: (1114, 551) for a button centred at (1115, 552), and (900, 552) inside a button spanning x 830-980.
- **Missed:** the 10 px discount code QX7-41B, read as "QXT-418". It was wrong in all three later tries at the default size as well.

**Image size** (Q6, 2 slots, 128K):

| Setting | Tokens, 1280x800 page | Prompt time, page / scan | 10 px code, 3 tries | IBAN | Button centre (1115, 552) | VRAM effect |
|---|---|---|---|---|---|---|
| default | ~1,050 | 0.67 / 1.30 s | 0/3 | right | (1113, 551) | - |
| `--image-min-tokens 2048` | ~2,140 | 1.34 / 1.27 s | 3/3 | right | (1113, 551) | none |
| `--image-min-tokens 4096` | ~4,190 | 2.85 / 2.77 s | 3/3 | right | (1114, 550) | +0.3 GB |
| `--image-max-tokens 512` | ~530 | 0.35 / 0.32 s | 0/3 | right | (1099, 554) | none |

`--image-min-tokens 2048` reads the small text at about 1.3 s per screenshot, with no extra VRAM. The scan is already above 2,048 tokens, so the setting leaves it as it was.

**Setups** (VRAM is the whole card, desktop included, after the image requests; generation speeds are tok/s):

| Setup | VRAM | Free | Short | ~94K prompt | Near-full prompt | Screenshot / scan prompt time |
|---|---|---|---|---|---|---|
| Q6, 2 slots, 160K, projector on CPU | 30,452 MiB | 2.1 GB | 139.0 | 95.5 | 72.6 at 161K (pp 1,477) | 14.4 / 40.1 s |
| Q6, 2 slots, 160K, projector on GPU | 31,767 MiB | 0.8 GB | 138.6 | 95.1 | 72.4 at 161K (pp 1,476) | 0.68 / 1.32 s |
| **Q6, 2 slots, 128K, projector on GPU** | 30,292 MiB | 2.3 GB | 140.1 | 85.5 | 84.8 at 129K (pp 1,696) | 0.67 / 1.33 s |
| Q6, 1 slot, 160K, projector on GPU | 31,168 MiB | 1.4 GB | 139.4 | 89.3 | 73.0 at 161K (pp 1,484) | 0.70 / 1.33 s |
| Q5_K_XL, 2 slots, 160K, min 2048 | 30,780-31,125 MiB | 1.5 GB | 147.1 | 87.5 | 76.0 at 161K (pp 1,502) | 1.28 / 1.30 s |
| Q5_K_XL, 3 slots, 160K, min 2048 | 31,359 MiB | 1.2 GB | 146.3 | 97.8 | - | 1.21 / 1.21 s |
| Q5_K_XL, 3 slots, 192K, min 2048 | 31,926-31,968 MiB | 0.6 GB | 136.4 | 87.2 (pp 1,178) | 60.4 at 194K (pp 759) | 2.29 / 7.60 s |

Prompt processing at ~94K is 2,000-2,080 tok/s in every setup except Q5 at 192K, where the card is full and prompt processing drops to 1,178 tok/s (759 at 194K) and the scan takes 7.6 s: it spills, so 192K is out. Q5_K_XL with `--image-min-tokens 2048` read the code 3/3 (at 2 and at 3 slots), plus the IBAN and the button. Whether Q5 matches Q6 on agent tasks is left to the bake-off (TASK-045).

**What the numbers say.**

- **Projector on the CPU: not usable for an agent.** It saves 1.3 GB, but a screenshot takes 14 s and a scanned page 40 s, against 0.7 and 1.3 s on the GPU. A computer-use agent looks at the screen at every step.
- **Today's 2 slots at 160K with the projector on the GPU do not fit.** 0.8 GB is left for the desktop, below the 1.5 GB kept since TASK-033.
- **With -kvu the slots share one context pool.** So `-c` is the total for all users at once, not a window per user. A third slot costs about 0.2-0.6 GB of VRAM, not a third more context.

**The 32 GB entry: A, chosen by the user on 2026-11-08.** All three options carry the projector on the GPU and `--image-min-tokens 2048`.

| Option | Quality | Users at once | Context (shared) | Free VRAM | Near-full speed |
|---|---|---|---|---|---|
| **A. Q6, 2 slots, 128K (recommended)** | Q6, as validated in TASK-034 | 2 | 128K | 2.3 GB | 84.8 tok/s |
| B. Q5_K_XL, 3 slots, 160K | Q5, unproven until the bake-off | 3 | 160K | 1.2 GB | about 76 tok/s |
| C. Q5_K_XL, 2 slots, 160K | Q5, unproven until the bake-off | 2 | 160K | 1.5 GB | 76.0 tok/s |

A was the recommendation:

- It keeps the quant the coding stack was validated on, and the most VRAM headroom.
- It is the fastest at a full prompt.
- 128K was the window before TASK-020 (decision-004); a session running alone can still use all of it.

The home install has few people at once, and the office is a separate 24 GB entry (m-8). B is the fallback if the bake-off shows two slots queue too much at home, and only if Q5 passes there. The trial entry `local-coder-vision` now carries A's flags. Taking A changes Claude Code's `CLAUDE_CODE_MAX_CONTEXT_TOKENS` and OpenCode's context limit to 131,072 when the entry becomes local-coder (TASK-045 or the m-5 integration).
