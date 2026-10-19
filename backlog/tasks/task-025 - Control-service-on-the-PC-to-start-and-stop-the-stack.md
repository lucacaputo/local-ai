---
id: TASK-025
title: Control service on the PC to start and stop the stack
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 14:31'
updated_date: '2026-10-19 16:04'
labels: []
milestone: m-3
dependencies:
  - TASK-022
references:
  - scripts/ai-up.ps1
  - scripts/ai-down.ps1
  - scripts/lib/stack.ps1
priority: high
ordinal: 25000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
When the user is away the stack is usually down, and ai-up can only be run on the PC. A small HTTP service reachable over the tailnet lets the user start and stop it remotely. It must only run ai-up and ai-down on request, so the AI stack still never runs unless asked (PRD F4, user decision 2026-10-19), and it uses the same identity check as the router. In this task it is started by hand; starting it at logon is a separate task.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 status, up and down endpoints on a loopback port: status reports whether the stack is up and the VRAM in use, up runs ai-up (game guard included) and returns its message, down runs ai-down
- [x] #2 Requests from a login not on the allowlist or without identity get 401, and nothing else is exposed: no other commands and no parameters passed through to the scripts
- [x] #3 Overlapping up and down requests are serialised: a request that arrives while another runs gets a clear busy answer
- [x] #4 The service holds no GPU memory, and every request is logged with its login and outcome under D:\local-ai\logs
- [x] #5 Tested from the Mac through the tailnet: up from a stopped stack, status, down with VRAM back at idle, and up refused by the game guard (stand-in process)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. scripts/control-service.py (Python standard library only, run with the LiteLLM venv interpreter that install.ps1 already provides): ThreadingHTTPServer on 127.0.0.1:4100; tailscale serve publishes it under /control on tailnet port 4000 (TASK-022; the path prefix is stripped). GET /health (no auth, for the launcher), GET /status (router, llama-swap, loaded model from the llama-server ports 10001/10002, VRAM, busy), POST /up and POST /down run ai-up.ps1 / ai-down.ps1 with no parameters.
2. Auth on everything but /health: Tailscale-User-Login on the same allowlist as the router (LOCAL_AI_ALLOWED_LOGINS, from Get-AllowedLogins) and no Origin or Sec-Fetch-Site (TASK-031); else 401. Only these routes; no parameters reach the scripts.
3. One lock for up/down: a second request while one runs gets 409 busy; status stays answerable meanwhile. ai-up/ai-down failures (game guard, partly running) come back as 422 with the first line of the script error.
4. Every request is logged (time, login, method, path, status, outcome) to D:\local-ai\logs\control.log; no headers or secrets.
5. scripts/start-control.ps1 [-Stop]: starts the service detached (Start-Detached) with the allowlist injected and waits for /health; -Stop ends it. Logon start and permanent publishing are TASK-026; here the /control route is added by hand for the test.
6. Tests: unit-like checks from WSL with curl through the tailnet name (identity attached): status, up from stopped, status, down, VRAM back; 401 without identity (loopback) and with Origin; 404/405; two concurrent up requests (one 409); game guard with a ping.exe copy under ...\steamapps\common\ (422 with the guard message); llama-server count and VRAM unaffected by the service (GPU process memory of the python process); then the user runs status/up/down with curl from the Mac.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Built scripts/control-service.py (Python standard library, LiteLLM venv interpreter, 127.0.0.1:4100) and scripts/start-control.ps1 [-Stop]. Tests from WSL through the tailnet name (same identity as the Mac): health 200; status; loopback without identity 401; Origin 401; Sec-Fetch-Site 401; GET /up 405; unknown route 404; POST /up?Force=1 started the stack normally (query ignored, no parameters reach the scripts); up again reported already running; down returned VRAM to idle; two concurrent up requests: second 409 busy while status kept answering (running: up); after a remote up the router route answered and status showed local-coder loaded (22,963 MiB); the service process holds 0 MiB of dedicated GPU memory; game guard with a ping.exe copy under ...\steamapps\common\FakeGame: up 422 with the ai-up message; /control route survives ai-down. Mac (user, curl): status down, up ok in 13.4 s, status up, down with VRAM back to 1,606 MiB; with the fake game running, up refused with the game message. control.log has one line per request (time, login, method, path, code, outcome). Afterwards: service stopped, /control route removed, stack down; TASK-026 installs it permanently. Note for TASK-027: the guard message ends with "use -Force", which a remote caller cannot do; the up output also carries the PC hint line "Use: scripts\claude-local.ps1".
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added a control service that starts and stops the stack on request, for use from another device. scripts/control-service.py (standard library only, run by the LiteLLM venv Python) listens on 127.0.0.1:4100 and is meant to be published under /control on tailnet port 4000; it has GET /health, GET /status (router, llama-swap, loaded model, VRAM, running action) and POST /up and /down, which run ai-up.ps1 and ai-down.ps1 without any parameters, game guard included. Requests need an allowlisted Tailscale login (the router allowlist) and must not come from a browser (no Origin or Sec-Fetch-Site), else 401; one up/down at a time (409 busy); failures come back as 422 with the script message; every request is logged to D:\local-ai\logs\control.log; the service holds no GPU memory. scripts/start-control.ps1 starts it detached with the allowlist injected, or stops it with -Stop. Tested from WSL through the tailnet and by the user from the Mac: status, up from stopped, down to idle VRAM, busy, auth refusals, and the game guard with a stand-in process. The service is not left running; starting it at logon and publishing /control permanently are TASK-026.
<!-- SECTION:FINAL_SUMMARY:END -->
