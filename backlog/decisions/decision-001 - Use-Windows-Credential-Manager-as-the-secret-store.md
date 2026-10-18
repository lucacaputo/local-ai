---
id: decision-001
title: Use Windows Credential Manager as the secret store
date: '2026-10-18 14:20'
status: accepted
---
## Context

The router master key and the client local key must never sit in plaintext in the repo or on disk (PRD F6). PRD O7 left the choice open between 1Password CLI and Windows Credential Manager, to be decided by what is already installed. Inventory (TASK-001): 1Password CLI and app are not installed; Credential Manager is built into Windows 11. Scripts run on PowerShell 5.1 only.

## Decision

Store the secrets in Windows Credential Manager and inject them into process environments at start from `ai-up.ps1`.

## Consequences

- No new software to install, and nothing in the repo or plaintext config holds a secret.
- PowerShell 5.1 has no built-in cmdlet to read a stored credential, so TASK-006 needs a small helper (P/Invoke on `CredRead`, or the SecretManagement module).
- Secrets are tied to the Windows user profile; remote devices keep their own local key copy.
- Switching to 1Password CLI later only changes the helper.
