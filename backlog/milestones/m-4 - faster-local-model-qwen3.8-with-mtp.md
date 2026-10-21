---
id: m-4
title: "Faster local model: Qwen3.8 with MTP"
---

## Description

Make the local models faster and better without giving up Q6-level quality: Qwen3.8-27B (same architecture as Qwen3.6-27B) with MTP speculative decoding, which the pinned llama.cpp build already supports. Options review: Claude Docs page "Local AI stack: options for m-4" (https://claude.ai/artifact/PMHgvtTgyojkztaed8EraB).

User decisions 2026-10-21: path 1 (Qwen3.8 + MTP on llama.cpp, Claude Code stays) plus an OpenCode trial for local models; Qwen3.8 runs next to Qwen3.6 and replaces it only after the quality check; Q6-level quality is fixed; the llama-server slot count (--parallel 1 or 2) is chosen from measurements.

Done when: a Qwen3.8 entry with MTP is the local coder on the PC and the Mac, measured faster than the Qwen3.6 Q6_K entry at no loss on our task set, and the OpenCode trial has a recorded verdict.

Out of scope: vLLM, SGLang, ExLlamaV3 and NVFP4 quants; a MoE model for local-light; Claude models in OpenCode (subscription logins are blocked in third-party tools).
