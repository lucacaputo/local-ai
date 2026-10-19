# Using the local AI stack from a Mac

The PC runs the router (`ai-up`); the Mac reaches it over Tailscale only. Claude Code on the Mac keeps
its own subscription login, and the router key lives in the macOS Keychain.

## One-time setup

1. **Tailscale on the Mac.** Install it from https://tailscale.com/download and sign in to the same
   tailnet as the PC. Check that the PC is listed (`tailscale status` or the menu bar app).
2. **PC address.** In the Tailscale app on the PC, or in the admin console, note the PC's address
   (a `100.x.y.z` IP or its MagicDNS name). It is shown as `tailnet http://...:4000` when `ai-up` finishes.
3. **Repo on the Mac.** `git clone git@github.com:lucacaputo/local-ai.git`. Only `scripts/mac/` and
   `config/claude-settings.json` are used.
4. **Key transfer.** On the PC run `scripts\copy-router-key.ps1` (copies the key without printing it and
   clears the clipboard after 60 s; if Windows clipboard history is on, clear it afterwards). Send it to the
   Mac with Universal Clipboard or any means that does not write it to a file or chat.
5. **Store it.** On the Mac:
   ```
   scripts/mac/setup-client.sh http://<pc-address>:4000
   ```
   It saves the URL in `~/.config/local-ai/router-url` and asks for the key at a hidden prompt
   (twice), storing it in the login Keychain as `local-ai/router-key`.

## Daily use

1. On the PC: `scripts\ai-up.ps1` (stop with `scripts\ai-down.ps1`).
2. On the Mac: `scripts/mac/claude-local.sh` (any arguments go to `claude`). `/model` shows the Claude
   models plus Local Coder and Local Light. The first local request loads the model (about 10 s).

The launcher unsets `ANTHROPIC_API_KEY` and `ANTHROPIC_AUTH_TOKEN` for Claude Code on purpose: either
would replace the subscription login and switch to API billing.

## Troubleshooting

- **Reachability:** `curl -s -o /dev/null -w '%{http_code}\n' http://<pc-address>:4000/v1/models`
  should print `401` (reachable, no key). A timeout means the stack is down (`ai-up`), Tailscale is off on
  one side, or the ACL blocks the Mac.
- **401 in Claude Code:** the Keychain key is wrong or was rotated. Rerun `setup-client.sh` (it updates the item);
  see [Rotating the key](#rotating-the-key).
- **Remove the key:** `security delete-generic-password -a "$USER" -s local-ai/router-key`.

## Rotating the key

The router and every client share one key (decision-005), so a leaked key is replaced everywhere.
Run on 2026-10-19 (TASK-017); these are the steps that worked.

1. **PC:** `scripts\init-secrets.ps1 -Rotate`. The new key replaces the old one in Credential Manager
   (still one `local-ai/router-key` item, check with `cmdkey /list`).
2. **PC:** `scripts\ai-down.ps1`, then `scripts\ai-up.ps1`. A running router keeps accepting the old key
   until it is restarted. After the restart the old key gets 401 and the new one 200, on loopback and on
   the tailnet address.
3. **Mac, before updating:** `scripts/mac/claude-local.sh` now fails with a 401: the Keychain still holds
   the old key.
4. **PC:** `scripts\copy-router-key.ps1`, and move the key to the Mac as in the one-time setup (step 4).
5. **Mac:** `scripts/mac/setup-client.sh http://<pc-address>:4000` and paste the new key at both prompts.
   `-U` updates the existing Keychain item instead of adding a second one.
6. **Mac:** `scripts/mac/claude-local.sh` works again. Check that only one key is stored (this prints one
   line per item, with its account, never the secret):
   ```
   security dump-keychain | awk '/^keychain:/{acct=""} /"acct"<blob>=/{acct=$0} /"svce"<blob>="local-ai\/router-key"/{print acct}'
   ```
   One line with your Mac user is expected. (`grep -c local-ai/router-key` on the dump counts each item
   twice, label and service, so it prints 2 for one item.)

Repeat steps 4-6 on every other device that uses the router.
