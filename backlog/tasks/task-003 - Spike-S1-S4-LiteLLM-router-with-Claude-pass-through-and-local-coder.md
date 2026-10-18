---
id: TASK-003
title: 'Spike S1/S4: LiteLLM router with Claude pass-through and local-coder'
status: Done
assignee:
  - '@claude'
created_date: '2026-10-18 14:13'
updated_date: '2026-10-18 15:12'
labels: []
milestone: m-0
dependencies:
  - TASK-002
documentation:
  - backlog/docs/doc-0001-PRD.md
priority: high
type: spike
ordinal: 3000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A single endpoint must serve both real Claude models (on the subscription OAuth login, not per-token API billing) and local models, so one Claude Code session can use either (PRD F1, R1, R7). LiteLLM docs do not show this mixed config, so it must be proven by test (O6). Router auth must use `x-litellm-api-key` via `ANTHROPIC_CUSTOM_HEADERS`, and neither `ANTHROPIC_AUTH_TOKEN` nor `ANTHROPIC_API_KEY` may be set. Fallbacks: F1 (separate `claude-local` profile) if the mixed config fails; F3 (OpenAI route to the local server) if the Anthropic route misbehaves with tools.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 LiteLLM runs from a `uv` venv at a pinned version (v1.81.14+), with no database
- [x] #2 `config/litellm.yaml` defines `anthropic/*` pass-through and `local-coder` pointing at the loopback llama-server
- [x] #3 Router rejects requests without the local key
- [x] #4 One Claude Code session on the subscription login calls a Claude model and `local-coder` through the router
- [x] #5 Evidence shows Claude requests use the subscription, not API billing
- [x] #6 Local deployment never receives the OAuth token
- [x] #7 A multi-step tool-use task completes on `local-coder` through the router
- [x] #8 Outcome is recorded: pass, or which fallback (F1/F3) was taken
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Install uv 0.13.1 with winget (decision-002); let uv fetch its own Python 3.12 (LiteLLM 1.106.0 needs >=3.10,<3.15), so no system Python is installed.
2. Create the venv at D:\local-ai\litellm-venv (outside the repo, decision-003) and install litellm[proxy]==1.106.0; record the resolved lock (uv pip freeze) in the notes.
3. Write config/litellm.yaml: wildcard anthropic/* (no api_key, so requests without a subscription token fail with 401 and can never fall back to API billing), local-coder -> llama-server, master_key from env var, no database, telemetry off.
4. Local route: try the openai/ provider (http://127.0.0.1:8080/v1) first, since the anthropic/ provider type forwards the client OAuth token to its api_base and would hand it to the local server (AC #6). Then test the anthropic/ route against llama-server as an experiment and record whether the token leaks.
5. Start the router on 127.0.0.1:4000 from a throwaway script with an ephemeral random master key kept only in that process environment (permanent secret handling is TASK-006); start llama-server by hand as in TASK-002.
6. Test with the real Claude login (default profile), env ANTHROPIC_BASE_URL=http://127.0.0.1:4000 and ANTHROPIC_CUSTOM_HEADERS=x-litellm-api-key: Bearer <key>, no ANTHROPIC_AUTH_TOKEN/ANTHROPIC_API_KEY: claude -p with a Claude model and with local-coder; request without the header must be rejected.
7. Evidence for AC #5/#6: LiteLLM debug log of outgoing request headers (token masked) per deployment, plus llama-server receiving no Authorization of the OAuth form.
8. Rerun the multi-step edit task on the scratch repo through the router with local-coder.
9. Record outcome (pass, or F1/F3). Stop for review.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Research (2026-10-18): LiteLLM docs (Claude subscription tutorial) confirm since v1.81.14 the proxy forwards Authorization: Bearer sk-ant-oat... to anthropic/ deployments and adds anthropic-beta: oauth-2025-04-20; the token overrides any api_key on the deployment; a deployment without api_key serves subscription users only (401 otherwise). The tutorial assumes Postgres for virtual keys; we use only the master key via x-litellm-api-key, no DB (R7). Docs say not to use ANTHROPIC_MODEL with a custom alias (Claude Code warns on unknown model names) - relevant for TASK-004. Risk to check: anthropic/ provider type for the local deployment may forward the OAuth token to llama-server (loopback only, but violates AC #6), hence openai/ route first. winget has uv 0.13.1; LiteLLM 1.106.0 requires Python >=3.10,<3.15.

Results (2026-10-18):

Setup: uv 0.13.1 installed via winget; uv fetched Python 3.12.15; venv D:\local-ai\litellm-venv with litellm[proxy]==1.106.0, no database. config/litellm.yaml: wildcard anthropic/* (no api_key), local-coder -> openai/local-coder at http://127.0.0.1:8080/v1, master_key from env LITELLM_MASTER_KEY, drop_params, telemetry off. Router on 127.0.0.1:4000 with a random per-run key held only in the process environment (spike scripts in D:\local-ai: spike-router.ps1, analyze.py; debug logs sanitized after each run, secret scan of logs, scripts and config found nothing).

Auth: no key -> HTTP 500, wrong key -> HTTP 400, correct key -> 200. The 500 is a LiteLLM quirk: without a DB the error handler hits ModuleNotFoundError: prisma instead of returning 401. Access is denied either way; note for hardening. Windows quirk: redirected output needs PYTHONUTF8=1 or the startup banner crashes (cp1252); carry into ai-up.ps1.

Model list: /v1/models returns local-coder plus anthropic/claude-* ids (note the anthropic/ prefix; matters for TASK-004 discovery labels).

Evidence AC #4-#6 (litellm debug log, tokens masked): Claude Code 2.1.302 on the normal login, ANTHROPIC_BASE_URL + ANTHROPIC_CUSTOM_HEADERS only (no ANTHROPIC_API_KEY/AUTH_TOKEN, none set in env or settings.json), claude -p --model claude-haiku-5-5 returned PONG; the outbound request to https://api.anthropic.com/v1/messages carried the forwarded client bearer plus anthropic-beta ...oauth-2025-04-20 and no x-api-key, and the deployment has no api_key configured, so API-key billing is impossible. (Claude Code's total_cost_usd is a list-price estimate, not a charge.) Local requests to http://127.0.0.1:8080 carried only Authorization: Bearer none (8/8 in the edit run, no Anthropic token), so the OAuth token never reaches llama-server. claude -p --model local-coder through the same router returned PONG.

Local route behaviour: with the openai/ provider, LiteLLM translates /v1/messages into the OpenAI Responses API and calls llama-server /v1/responses (not /v1/chat/completions). Text and tool use work; reasoning tokens count toward max_tokens (a 60-token cap returned empty content, 800 returned "OK"); the thinking block is not passed back. The anthropic/ provider type for the local deployment was not tried (the openai/ route already passed and avoids forwarding the token); revisit only if the Responses route causes trouble.

S2 preview: Claude Code reports contextWindow 200000 for local-coder (server is 64K), logs [claude-code:unrecognized_model], and shows costUSD with basis unknown - to handle in TASK-004.

AC #7: multi-step edit task on the scratch TS repo through the router with --model local-coder on the real login: success in 41 s / 19 turns, 18 tool results, 4 errors, all wrong-path Reads of the form C:\Users\caput\.claude\projects\D--local-ai-scratch-ts-demo\src\x.ts (the Claude Code per-project data dir) that the model corrected itself. This shows the TASK-002 path error was not caused by the throwaway CLAUDE_CONFIG_DIR. I re-ran npm test myself: 4/4 pass, calcTotal gone, tests for 10 percent discount and RangeError present. An earlier edit run was invalid (my script's git reset ran on Windows where git is missing, so the repo already contained the edits) and was discarded.

Outcome: S1 pass with mixed config (wildcard anthropic/* + local-coder); S4 via router pass on the OpenAI/Responses route; no fallback (F1) needed. Servers stopped (VRAM idle).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Proved the mixed router works: LiteLLM 1.106.0 (uv venv on D:, Python 3.12.15, no DB) serves the wildcard anthropic/* route on the user's subscription login and local-coder via llama-server, behind x-litellm-api-key. Evidence from LiteLLM debug logs: the client OAuth bearer and oauth beta header go to api.anthropic.com with no x-api-key and no deployment api_key; llama-server only ever sees "Bearer none". A multi-step edit task on local-coder through the router passed (4/4 tests verified independently). config/litellm.yaml added. No fallback needed (F1 not required; local route uses the openai/ provider via the Responses API).

Risks/follow-ups (not created as tasks): missing router key returns 500 (prisma import error in LiteLLM without DB) instead of 401; PYTHONUTF8=1 required on Windows; /v1/models ids carry an anthropic/ prefix and Claude Code assumes a 200K context for local-coder (TASK-004); wrong-path Reads recur on the normal profile (TASK-004 criterion #6); the anthropic/ provider route for local models was not tested; per-run router key is ephemeral until TASK-006.
<!-- SECTION:FINAL_SUMMARY:END -->
