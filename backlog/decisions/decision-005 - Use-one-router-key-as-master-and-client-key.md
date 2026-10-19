---
id: decision-005
title: Use one router key as master and client key
date: '2026-10-18 16:08'
status: >-
  accepted for calls made on the PC; superseded for remote devices by
  decision-008 (they get in by Tailscale login and hold no key, TASK-023,
  TASK-024)
---
## Context

TASK-006 asked for a router master key and a separate client local key in the secret store (PRD F6). LiteLLM can only issue separate client keys as virtual keys, which need a database; the router runs without one (PRD R7, single user).

## Decision

Use one random key, stored in Windows Credential Manager under `local-ai/router-key`. It is both the LiteLLM master key (`LITELLM_MASTER_KEY`, injected into the router process only) and the key clients send as `x-litellm-api-key` (built into the Claude Code process environment by `scripts/claude-local.ps1`). The key is generated in memory by `scripts/init-secrets.ps1` and never printed or written to a file.

## Consequences

- One secret, one place, nothing to keep in sync; rotation is `init-secrets.ps1 -Rotate` plus updating remote clients.
- A client holding the key has admin rights on the router. Without a database most admin features do not exist, and the router is reachable only over loopback and the tailnet.
- Remote devices (later milestone) need the same key stored in their own secret store.
- If other users or per-device keys are ever needed, add a database and virtual keys, and revisit this decision.
