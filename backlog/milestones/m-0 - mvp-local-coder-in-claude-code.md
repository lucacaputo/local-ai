---
id: m-0
title: "MVP: Local coder in Claude Code"
---

## Description

First usable stack on the PC (PRD doc-0001, phases 1-2).

Scope:
- Spikes S1-S4 run, each passed or switched to its fallback (F1-F3).
- llama.cpp (CUDA 12.8+, Blackwell) serving Qwen3.6 27B Q4_K_M at 64K context through llama-swap, with idle ttl unload.
- LiteLLM router: Anthropic pass-through on the subscription OAuth plus local-coder / local-light (alias), local key auth.
- Claude Code on the PC shows Claude and local models in one /model list.
- scripts/install.ps1, scripts/ai-up.ps1, scripts/ai-down.ps1.
- Secrets injected from a secret store, none in plaintext (F6).
- Router bound to loopback + Tailscale interface only, llama-swap/llama-server on loopback (N2).

Done when:
- ai-up brings the stack healthy in under 2 minutes; ai-down leaves VRAM near idle.
- /model on the PC lists Claude and local models, and each one works.
- A multi-step edit task completes with local-coder, tool calls succeeding.
- Model unloads after the idle ttl.
- No secrets in the repo or plaintext config.

Out of scope (later milestones): model bake-off, remote device setup and testing, LAN port-scan check (A4), README and hardening.
