# Using the local AI stack from a Mac

The PC runs the router (`ai-up`); the Mac reaches it over Tailscale only. Claude Code on the Mac keeps
its own subscription login. The Mac stores no router key: `tailscale serve` tells the router which
Tailscale login is calling, and the router lets in the logins on its allowlist (TASK-023, TASK-024).

## One-time setup

Nothing has to be done on the PC, so this also works away from home.

1. **Tailscale on the Mac.** Install it from https://tailscale.com/download and sign in with the same
   Tailscale account as the PC. Check that the PC is listed (`tailscale status` or the menu bar app).
2. **PC name.** The router answers on the PC's MagicDNS name, `http://caps.<tailnet>.ts.net:4000`, which
   `ai-up` prints as its `tailnet` line (here `http://caps.tail0144cb.ts.net:4000`). The `100.x.y.z` IP does
   not work: the router is published in HTTP mode, which only answers on the name.
3. **Repo on the Mac.** `git clone git@github.com:lucacaputo/local-ai.git`. Only `scripts/mac/` and
   `config/claude-settings.json` are used.
4. **Store the URL.** On the Mac:
   ```
   scripts/mac/setup-client.sh http://caps.tail0144cb.ts.net:4000
   ```
   It saves the URL in `~/.config/local-ai/router-url`, removes a router key left in the Keychain by the
   older key-based setup, and checks that the router accepts this Mac's login (it says so, or tells you
   that the stack is down).

The allowlist is the login the PC itself is signed in to Tailscale with, so a Mac signed in with the same
account needs nothing else. Another account can be allowed by listing its login in
`D:\local-ai\allowed-logins.txt` on the PC (one per line) and restarting the stack.

## Daily use

1. On the PC: `scripts\ai-up.ps1` (stop with `scripts\ai-down.ps1`).
2. On the Mac: `scripts/mac/claude-local.sh` (any arguments go to `claude`). `/model` shows the Claude
   models plus Local Coder, Local Light and Local Coder Q6. The first local request loads the model
   (about 10 s, 18 s for the Q6_K).

The launcher sends `x-litellm-api-key: tailscale-identity`. That is a fixed marker, not a secret: LiteLLM
only forwards the Claude subscription token to Anthropic when that header is present. It also unsets
`ANTHROPIC_API_KEY` and `ANTHROPIC_AUTH_TOKEN` for Claude Code on purpose: either would replace the
subscription login and switch to API billing.

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
- **000 or a timeout:** the stack is down (`ai-up`), Tailscale is off on one side, or the ACL blocks the Mac.
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
