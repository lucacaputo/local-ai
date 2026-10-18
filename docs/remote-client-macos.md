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
- **401 in Claude Code:** the Keychain key is wrong or was rotated. Rerun `setup-client.sh` (it updates the item).
- **Rotating the key:** `scripts\init-secrets.ps1 -Rotate` on the PC, restart the stack, rerun
  `setup-client.sh` on every device.
- **Remove the key:** `security delete-generic-password -a "$USER" -s local-ai/router-key`.
