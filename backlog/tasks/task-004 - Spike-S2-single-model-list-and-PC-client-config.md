---
id: TASK-004
title: 'Spike S2: single /model list and PC client config'
status: Done
assignee:
  - '@claude'
created_date: '2026-10-18 14:13'
updated_date: '2026-10-18 15:50'
labels: []
milestone: m-0
dependencies:
  - TASK-003
documentation:
  - backlog/docs/doc-0001-PRD.md
priority: high
type: spike
ordinal: 4000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The user switches models through `/model` and wants Claude and local models in one list with friendly names (PRD F1, F2, R2). Claude Code must also know the real local context window (64K) or auto-compaction will fire too late and requests will fail. The working client setup becomes the committed PC config, so it must not hold secrets. Fallback F2: `ANTHROPIC_CUSTOM_MODEL_OPTION` plus an explicit compaction threshold.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 `/model` on the PC lists real Claude models plus `local-coder` and `local-light` with readable labels
- [x] #2 Selecting each listed model works, including session-only switching
- [x] #3 Context window Claude Code assumes for local models matches the server (128K, raised from 64K after the compaction test showed 64K leaves too little room), and auto-compaction triggers before the limit in a long session
- [x] #4 Chosen mechanism (discovery vs custom entries) and labels are recorded (O5); if F2 was needed, that is recorded
- [x] #5 A secret-free PC client config template (`settings.json` / env) is committed; the local key is supplied through the environment (reading it from the secret store is TASK-006)
- [x] #6 Any wrong-path Read/Edit tool calls with the normal profile are counted and recorded (the throwaway-profile run in TASK-002 showed many); if they recur, the cause is investigated
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add local-light to config/litellm.yaml (same upstream as local-coder for now; TASK-005 re-points it through llama-swap).
2. Draft a secret-free Claude Code settings file (config/claude-settings.json) with a modelPicker lineup (local-coder, local-light) and the env vars: CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1, CLAUDE_CODE_MAX_CONTEXT_TOKENS=65536. Load it per launch with --settings so the global settings stay untouched. The base URL and x-litellm-api-key header stay in the launcher environment (key from the secret store in TASK-006; ephemeral for this spike).
3. Non-interactive checks with claude -p --output-format json: modelUsage.contextWindow for local-coder (expect 65536, was 200000), the unrecognized_model warning, and that Claude models keep their native window.
4. Compaction test: a long local-coder session whose context exceeds 64K; confirm compaction fires (compact boundary in stream-json) and llama-server never reports context overflow.
5. Compare discovery on vs off vs ANTHROPIC_CUSTOM_MODEL_OPTION for picker cleanliness (O5); decide, record labels. Fallback F2 if the window or compaction misbehave: ANTHROPIC_CUSTOM_MODEL_OPTION plus CLAUDE_CODE_AUTO_COMPACT_WINDOW.
6. The /model picker itself is interactive: prepare a throwaway launcher (router + llama-server + interactive claude in one window) and ask the user to look at /model, switch to each entry (Enter and the s session-only key) and report.
7. Wrong-path Read/Edit calls: count them in the real profile runs (criterion #6).
8. Commit the secret-free template; record the outcome. Stop for review.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Research (2026-10-18): modelPicker format found in the Claude Code 2.1.302 binary (not in the public docs/schema): { replaceBuiltInOptions?: boolean, options: [{ model, label?, description?, behavesAs? }] }; honored only from user settings, --settings or managed settings (ignored in project/local settings); needs v2.1.242+. Docs: CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1 fills the picker from /v1/models (default timeout 3 s, CLAUDE_CODE_GATEWAY_MODEL_DISCOVERY_TIMEOUT_MS); for IDs not starting with claude- and without [1m], CLAUDE_CODE_MAX_CONTEXT_TOKENS applies directly, so local-coder can be given 65536 while Claude models keep their own window. Router /v1/models returns anthropic/-prefixed ids (23 of them) plus local-coder; the prefix may clutter or mislabel discovered rows.

Results so far (2026-10-18, Claude Code 2.1.302, LiteLLM 1.106.0, llama.cpp b11719):

Context window (AC #3): config/claude-settings.json (secret-free, loaded with --settings) sets CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1, CLAUDE_CODE_MAX_CONTEXT_TOKENS and a modelPicker lineup (Local Coder, Local Light). With it, claude -p reports contextWindow 65536 for local-coder and local-light (was 200000) while claude-haiku-5-5 keeps 1000000. The [claude-code:unrecognized_model] line is only debug output. local-light was added to config/litellm.yaml (same upstream as local-coder for now).

Budget finding: /context shows a fixed 33K autocompact buffer, so a 65K window compacts at ~36K tokens, and a real Claude Code request is ~19K tokens (one first run was 48K, likely a one-off connector/skill sync). That leaves ~13K of working room at 64K: with 7 real source files (~50K tokens) Claude Code compacted 3 times then stopped with "Autocompact is thrashing". Compaction itself triggered before the server limit (server never overflowed at 64K). Recommendation: raise llama-server to -c 131072 and set CLAUDE_CODE_MAX_CONTEXT_TOKENS=131072 (O4). Measured at 128K: VRAM 23.6 GB total (KV 4.35 GiB), 94.5K-token prompt: 2345 tok/s prompt processing, 56.5 tok/s generation (N1 still met), short prompt 77 tok/s. Compaction test at 128K, 14 real source files read one per turn: auto compaction fired at an estimated 99.6K tokens (~131072 minus 33K), server peak 94.7K, no overflow, all 14 markers returned correctly.

Risks: (1) several Read calls in one turn (the model batches them) can add >100K tokens at once and overflow the server before compaction can run (seen once: 145679 > 131072, HTTP 400 ContextWindowExceededError); a lower assumed window than the server context or a tool-result size cap would add margin. (2) Claude Code's token estimate is ~2x too low for random-word text (tokenizer mismatch), fine for code/English. (3) Wrong-path tool calls (criterion #6): 4/18 results in the earlier edit run and 7/7 first Reads in the compaction runs. The model builds absolute paths from nothing: either under the per-project data dir C:\Users\caput\.claude\projects\<slug>\ (auto-memory path is the only absolute path in view) or, with CLAUDE_CODE_DISABLE_AUTO_MEMORY=1, an invented C:\Users\luzzu\Documents\prj\wavefunc\. It recovers via Glob when allowed. Not a config problem; a model weakness for the bake-off, possible mitigation via a CLAUDE.md/prompt that states the cwd.

Remaining: interactive /model picker check (discovery on vs off, Enter and session-only s key) via D:\local-ai\try-model-list.ps1 [-NoDiscovery], then decide labels and mechanism (O5).

Interactive picker check by the user (2026-10-18, via D:\local-ai\try-model-list.ps1): /model shows the built-in Claude rows plus Local Coder and Local Light; with and without CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY the list looked the same, so discovery adds nothing here and is dropped from config/claude-settings.json (no extra 3 s startup call, no anthropic/-prefixed ids). Mechanism chosen (O5): modelPicker rows via --settings/user settings + CLAUDE_CODE_MAX_CONTEXT_TOKENS; ANTHROPIC_CUSTOM_MODEL_OPTION not needed (F2 not used). Selecting Local Light with the session-only s key worked. I confirmed it is served locally: claude -p --model local-light reports modelUsage key local-light and llama-server completes one request per call. Its answer to "who are you" ("Claude ... trained by Anthropic") is just the identity line of Claude Code's system prompt, so self-description is not evidence; check /status or the server log. Note: Enter in the picker saves the model as the default in user settings (the s key does not).

Observed in the user's second session log: Claude Code's startup request to claude-opus-5-5 through the router returned 429 rate_limit_error from Anthropic ("Error", request_id req_011Cg9xDVFjhng9vxgtgoMfA); LiteLLM retried twice. Cause unknown (plan usage limit or transient); not caused by routing since the same login worked via the router earlier. Watch for it.

Launcher pitfalls found: my spike scripts start servers with ephemeral keys on fixed ports 4000/8080, so a leftover session makes the next router fail to bind and a health check can hit the old router (wrong key shows as 400 "No connected db"); cleanup by process name kills every litellm/llama-server. ai-up/ai-down (TASK-009) must check ports, track PIDs and refuse or reuse cleanly.

Decision (user, 2026-10-18): adopt a 128K local context: llama-server -c 131072 and CLAUDE_CODE_MAX_CONTEXT_TOKENS=131072 (config/claude-settings.json). Hand-off for TASK-005: the proven launch command is now the TASK-002 one with -c 131072 (D:\local-ai\run-server.cmd); the old 64K variant is run-server-64k.cmd.

Criterion #5 is only partly met: config/claude-settings.json and config/claude-local-env.example.ps1 are secret-free templates, but the local key is not yet read from the secret store (the header value is a placeholder, ephemeral key in the spike). Left unchecked until TASK-006 wires the store, or the criterion is reworded.

Criterion #6 counts: edit task via router 4/18 tool results were wrong-path Reads; compaction runs 7/7 first Reads (relative filenames). Cause investigated: not config (also with auto-memory off, the model then invents paths like C:\Users\luzzu\Documents\prj\wavefunc); it is model behaviour, recoverable with Glob. Carried to the bake-off.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Got one /model list on the PC with the built-in Claude rows plus Local Coder and Local Light (modelPicker rows from config/claude-settings.json, loaded with --settings; gateway discovery adds nothing and was dropped). Claude Code now assumes the real local window: CLAUDE_CODE_MAX_CONTEXT_TOKENS=131072 while Claude models keep 1M. The 64K window proved too small (33K fixed compaction buffer + ~19K base prompt left ~13K; compaction thrashed), so the local context is raised to 128K (llama-server -c 131072): 23.6 GB VRAM total, 56 tok/s at a 94K prompt, compaction fired at ~99.6K with no server overflow when reads arrive one per turn. config/litellm.yaml gained local-light; secret-free templates added (claude-settings.json, claude-local-env.example.ps1).

Risks/follow-ups (not created as tasks): parallel Read calls can add >100K tokens in one turn and overflow the server before compaction runs (a lower assumed window would add margin); wrong-path Reads are model behaviour (bake-off); a 429 from Anthropic was seen once at startup; launcher scripts must check ports and track PIDs (TASK-009); the local key still has to come from the secret store (TASK-006); TASK-005 must use -c 131072.
<!-- SECTION:FINAL_SUMMARY:END -->
