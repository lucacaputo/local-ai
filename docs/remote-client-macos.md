# Using the local AI stack from a Mac

The PC runs the router (`ai-up`); the Mac reaches it over Tailscale only. OpenCode is the client for the
local models, Claude Code for the Claude models (TASK-035, TASK-038); Claude Code on the Mac keeps its own
subscription login. The Mac stores no router key: `tailscale serve` tells the router which
Tailscale login is calling, and the router lets in the logins on its allowlist (TASK-023, TASK-024).

## One-time setup

Nothing has to be done on the PC, so this also works away from home.

1. **Tailscale on the Mac.** Install it from https://tailscale.com/download and sign in with the same
   Tailscale account as the PC. Check that the PC is listed (`tailscale status` or the menu bar app).
2. **PC name.** The router answers on the PC's MagicDNS name, `http://caps.<tailnet>.ts.net:4000`, which
   `ai-up` prints as its `tailnet` line (here `http://caps.tail0144cb.ts.net:4000`). The `100.x.y.z` IP does
   not work: the router is published in HTTP mode, which only answers on the name.
3. **Repo on the Mac.** `git clone git@github.com:lucacaputo/local-ai.git`. Only `scripts/mac/`,
   `config/claude-settings.json` and `config/opencode.json` are used.
   **OpenCode**, at the pinned version: `npm install -g opencode-ai@1.19.3` (needs Node.js; check with
   `opencode --version`). Keep it on 1.19.3 until the pin in `scripts/versions.psd1` changes.
4. **Store the URL.** On the Mac:
   ```
   scripts/mac/setup-client.sh http://caps.tail0144cb.ts.net:4000
   ```
   It saves the URL in `~/.config/local-ai/router-url`, removes a router key left in the Keychain by the
   older key-based setup, and checks that the router accepts this Mac's login (it says so, or tells you
   that the stack is down). It also says when OpenCode is missing or not at the pinned version.

The allowlist is the login the PC itself is signed in to Tailscale with, so a Mac signed in with the same
account needs nothing else. Another account can be allowed by listing its login in
`D:\local-ai\allowed-logins.txt` on the PC (one per line) and restarting the stack.

## Daily use

1. Start the stack: `scripts/mac/ai-remote.sh up` on the Mac (see below), or `scripts\ai-up.ps1` at the PC.
2. On the Mac, for the local models: `scripts/mac/opencode-local.sh` (any arguments go to `opencode`;
   `--auto` skips the shell-command prompts for the session). It lists Local Coder and Local Light. For the
   Claude models: `scripts/mac/claude-local.sh` (any arguments go to `claude`); its `/model` shows the Claude
   models plus Local Coder and Local Light. The first local request loads the model (about 12 s).
3. Stop it when done: `scripts/mac/ai-remote.sh down` (at the PC: `scripts\ai-down.ps1`). A loaded model
   holds about 29 GB of the GPU's memory.

`opencode-local.sh` sets `OPENCODE_CONFIG` to the repo's `config/opencode.json`, the router URL saved by
`setup-client.sh`, and `tailscale-identity` as the key, the same non-secret marker; the router lets the
Mac in by its Tailscale login. The config (models, effort, permissions, skills) is described in the README.

`claude-local.sh` sends `x-litellm-api-key: tailscale-identity`. That is a fixed marker, not a secret: LiteLLM
only forwards the Claude subscription token to Anthropic when that header is present. It also unsets
`ANTHROPIC_API_KEY` and `ANTHROPIC_AUTH_TOKEN` for Claude Code on purpose: either would replace the
subscription login and switch to API billing.

## Starting and stopping the stack from the Mac

`scripts/mac/ai-remote.sh status`, `up` or `down` asks the control service on the PC to report on, start or
stop the stack (TASK-025 to TASK-027). The service is published under `/control` on the router's address and
lets in the same Tailscale logins as the router, with no key. The PC needs to be on (not asleep) with the user
logged in; a locked screen is fine. The control service must also be installed once at the PC with
`scripts\install-control.ps1`, which starts it at every logon. It never starts the stack by itself.

```
$ scripts/mac/ai-remote.sh up
Starting the stack on the PC (about 15 s)...
Stack healthy in 13.6 s: llama-swap http://127.0.0.1:8080, router http://127.0.0.1:4000, tailnet http://caps.tail0144cb.ts.net:4000. The model loads on the first request.
Start OpenCode (local models) with: /Users/<you>/local-ai/scripts/mac/opencode-local.sh
Start Claude Code (Claude models) with: /Users/<you>/local-ai/scripts/mac/claude-local.sh
$ scripts/mac/ai-remote.sh status
Stack up: no model loaded yet (the first request loads one). VRAM: 1247 of 32607 MiB used.
$ scripts/mac/ai-remote.sh down
Stopping the stack on the PC...
Stopped: tailnet publishing, router (pid 13456), llama-swap (pid 24428).
VRAM used: 1251 MiB -> 1241 MiB in 1 s (idle before ai-up: 1241 MiB).
```

The loopback addresses in these lines are the PC's own. From the Mac only the `tailnet` address applies.

| Message | Meaning |
|---|---|
| `Stack is already running (...). Nothing started.` | `up` while the stack was already up; nothing changed |
| `The PC did not start the stack: Not starting: game process running: ...` | The game guard: a game is running, or too little GPU memory is free. Close the game at the PC, then try again. `-Force` exists only at the PC |
| `busy: up is running` | Another `up` or `down` is still running; `status` shows which |
| `not authorised: ...` | This Mac's Tailscale login is not on the PC's allowlist (another account, or an `allowed-logins.txt` that does not list it). If the message adds `the PC has no allowed logins yet`, Tailscale is not signed in on the PC |
| `Cannot resolve caps....: Tailscale is off on this Mac` | Turn Tailscale on |
| `The PC does not answer: ...` | Shown after a 10 s wait. The PC is asleep or off, Tailscale is off on the PC, or the control service was never installed. These cases look the same from the Mac |
| `The PC is on, but its control service is not running` | The scheduled task restarts it within 10 minutes, or run `scripts\install-control.ps1` at the PC |
| `The PC does not publish the control service (/control)` | The stack runs but `/control` is not published: run `scripts\install-control.ps1` at the PC |

Exit status: 0 done, 1 refused or failed on the PC, 2 usage or no router URL, 3 PC not reachable.

## Troubleshooting

Check the router from the Mac:
```
curl -s -o /dev/null -w '%{http_code}\n' -H 'x-litellm-api-key: tailscale-identity' http://caps.tail0144cb.ts.net:4000/v1/models
```
- **200:** reachable and this Mac's login is accepted.
- **401:** reachable, but the login is not on the PC's allowlist (a different Tailscale account, or an
  `allowed-logins.txt` that does not list it).
- **404:** the URL uses the IP instead of the name, or the stack is down while other routes on the port
  are published.
- **000 or a timeout:** the stack is down (`ai-remote.sh up`), Tailscale is off on one side, or the ACL blocks the Mac.
- **Old key left in the Keychain:** rerun `setup-client.sh`, or
  `security delete-generic-password -s local-ai/router-key`.

## Rotating the key

The router key is only used on the PC now (by `scripts\claude-local.ps1` and as the LiteLLM master key),
so a rotation does not touch the Mac. Tested on 2026-10-19 (TASK-017):

1. **PC:** `scripts\init-secrets.ps1 -Rotate`. The new key replaces the old one in Credential Manager
   (still one `local-ai/router-key` item, check with `cmdkey /list`).
2. **PC:** `scripts\ai-down.ps1`, then `scripts\ai-up.ps1`. A running router keeps accepting the old key
   until it is restarted. After the restart the old key gets 401 and the new one 200.

Clients set up before TASK-024 kept a copy of the key in their Keychain; rerunning `setup-client.sh`
removes it. To check that none is left (prints one line per item, never the secret):
```
security dump-keychain | awk '/^keychain:/{acct=""} /"acct"<blob>=/{acct=$0} /"svce"<blob>="local-ai\/router-key"/{print acct}'
```
No output means no key is stored. (`grep -c local-ai/router-key` on the dump counts each item twice,
label and service.)
