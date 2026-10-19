---
id: m-3
title: "Remote setup and control over Tailscale"
---

## Description

Use the stack from the user's own devices without being at the PC: remote clients authenticate with their Tailscale identity instead of the shared router key, and a small control service on the PC starts and stops the stack on request.

User decisions 2026-10-19: the Tailscale login is the credential for remote devices (the key stays for calls made on the PC); the control service runs at logon, uses no GPU and only runs ai-up/ai-down when asked, so the AI stack still never starts by itself; remote start is a separate command on the Mac.

Done when: a Mac on another network sets itself up without touching the PC, starts the stack, uses local and Claude models in Claude Code, and stops it again.

Out of scope: Wake-on-LAN (the PC must be on with the user logged in), idle shutdown of the whole stack, phone clients, other users, claude-local.sh starting the stack by itself (follow-up).
