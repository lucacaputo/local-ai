---
id: TASK-041
title: Sandbox image and one OpenClaw container on Docker Desktop
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-08 17:43'
updated_date: '2026-11-08 23:08'
labels: []
milestone: m-5
dependencies: []
references:
  - 'https://docs.openclaw.ai/gateway/local-models'
  - 'https://docs.openclaw.ai/gateway/security'
documentation:
  - backlog/docs/doc-004 - Agent-stack-changes-and-decisions.md
priority: high
type: task
ordinal: 41000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
decision-010 and decision-011: each user's OpenClaw runs in its own Linux container with Chromium, a working folder and a shell, from one image the repo builds from pinned versions. The container is the sandbox, so OpenClaw's own tool sandbox stays off and no nested Docker is used. This task builds the image and runs one container for the owner, reached over the tailnet, as the base for the rest of m-5. Several users, sign-in and the portal belong to m-6.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Docker Desktop (WSL2 backend), OpenClaw and Chromium are pinned in scripts/versions.psd1 and the README pin list, and install.ps1 -CheckOnly reports Docker Desktop and the sandbox image
- [x] #2 The repo builds the sandbox image from pinned inputs: OpenClaw, Chromium, Python and the office file libraries the bake-off needs
- [x] #3 A script creates and starts the owner's container with a named volume for its home folder; browser logins, files and OpenClaw state survive a container restart, and a reset deletes them
- [x] #4 OpenClaw uses the router as an OpenAI-compatible provider with image input and the window and output limits of its slot
- [x] #5 Only the tools the bake-off needs are allowed, and plugins and skills come only from an allowlist in the repo
- [ ] #6 The owner reaches the OpenClaw web interface from the Mac over the tailnet, and no other port of the container is reachable
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Image (sandbox/Dockerfile): FROM the official ghcr.io/openclaw/openclaw:2026.9.36-browser pinned by digest (extended-stable line: security fixes, no weekly feature churn; Node 24.22.1, Chromium 1243 via Playwright, Python 3.11). Adds a Python venv with the office libraries (openpyxl, python-docx, pypdf) from a hash-locked requirements file, and moves the Playwright browsers out of /home/node so the home volume does not hide them.
2. Policy from the repo, not from the volume: config/openclaw.json5 baked read-only (OPENCLAW_CONFIG_PATH, OPENCLAW_CONFIG_READONLY=1). Router as an openai-completions provider at host.docker.internal:4000, model local-coder-vision (decision-013 option A: 131072 context, image input), output cap as the coding clients (32000). Tools: an explicit allowlist of what the bake-off needs (browser, files, shell in the container, web fetch), the rest denied. Plugins: allowlist of the bundled ones needed; skills: none bundled. OpenClaw's own sandbox off, exec runs in the container without approvals (the container is the sandbox). Update check and telemetry off.
3. Secrets: gateway token and (until TASK-042) the router key from Credential Manager, passed as env vars at container start, referenced by SecretRef; nothing written in the image or the repo. TASK-042 replaces the router key with a sandbox credential limited to local models.
4. scripts/sandbox.ps1: build | start | stop | reset | status for one user (owner). Container openclaw-<user>, named volume openclaw-<user>-home at /home/node, gateway bound inside the container and published only on host loopback; tailscale serve publishes it over HTTPS on the tailnet (Control UI needs a secure context), allowedOrigins set to that origin. Memory and shm limits from measurement.
5. versions.psd1 + README: Docker Desktop (checked, not installed, like the NVIDIA driver), OpenClaw image digest; install.ps1 -CheckOnly reports Docker Desktop and the sandbox image, and install builds the image.
6. Verify: restart keeps browser login, files and OpenClaw state, reset deletes them; a turn through the router with an image; only allowed tools offered; Control UI from the Mac over the tailnet (user); port scan of the container from the host and the tailnet shows only the gateway. Finish the bench OpenClaw driver and run one bake-off task through it (TASK-040 AC4).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Built and running. Findings: the image's entrypoint runs doctor --fix, which refuses a read-only config, so the sandbox starts the gateway directly (tini, node openclaw.mjs gateway); state needs OPENCLAW_STATE_DIR (else it goes next to the config). Defaults that had to go: 14 plugins (now 1: browser), memory-core's scheduled dreaming job (would wake the model), remote model catalog download, update check, Tool Search (hid browser/web_fetch/ask_user behind search tools), 14 bundled skills incl. clawhub (skills.allowBundled [] does not restrict; agents.defaults.skills does). Chromium's own sandbox cannot start in the container (no user namespaces): browser.noSandbox true; before that the agent started its own Chromium with --no-sandbox through exec. The pdf tool is not offered with this model (needs native PDF input); pypdf in the shell covers it. web_fetch refuses private addresses (only an all-or-nothing switch), so fixture sites go through the browser.

Verified: config validates; a turn through the router answers from local-coder-vision with contextTokens 131072; a browser screenshot of a fixture page read correctly; offered tools = the 12 allowed, skills = browser-automation, plugins 1/66. Persistence: file, browser cookie and session survive docker restart and a recreate (sandbox.ps1 start); reset removes all three. Ports: only 127.0.0.1:18789 published; CDP 18800/18791/9222 closed on the host; 18789 not reachable on the tailnet IP. RAM: about 1.3 GB with Chromium open (limit 4 GB). install.ps1 -CheckOnly reports Docker Desktop 4.98.0 and the sandbox image. Open: tailnet HTTPS (Serve not enabled on the tailnet yet; needs the user) and the Control UI from the Mac.
<!-- SECTION:NOTES:END -->
