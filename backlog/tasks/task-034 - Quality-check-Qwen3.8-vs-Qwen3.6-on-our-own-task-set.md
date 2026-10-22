---
id: TASK-034
title: 'Quality check: Qwen3.8 vs Qwen3.6 on our own task set'
status: Done
assignee:
  - '@claude'
created_date: '2026-10-21 20:45'
updated_date: '2026-10-22 21:31'
labels: []
milestone: m-4
dependencies:
  - TASK-033
references:
  - 'https://huggingface.co/unsloth/Qwen3.8-27B-GGUF/discussions/135'
  - 'https://github.com/ggml-org/llama.cpp/issues/27615'
documentation:
  - backlog/docs/doc-002 - PRD-changes-and-implementation-log.md
  - backlog/docs/doc-0001-PRD.md
priority: high
type: task
ordinal: 34000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Qwen3.8-27B reports large agentic gains over Qwen3.6-27B (Terminal-Bench 2.1 73.0 vs 63.4, SWE-bench Pro 61.7 vs 53.5), but these are vendor numbers with no independent replication found. Two community reports matter for us: unsloth dynamic quants looping or not closing on long deep-thinking tasks (unsloth discussion #135, unconfirmed), and generation slowing on long outputs when Claude Code sends many tools (llama.cpp #27615, fix scoped to another chat format). The PRD bake-off (section 6, R4 gate) was skipped in m-1; this is a small version of it. User decision 2026-10-21: Qwen3.8 replaces Qwen3.6 only if it passes this check.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A fixed task set of at least 6 tasks is written down so it can be re-run: the ts-demo edit, a longer multi-step edit, a code review of a real diff, a PR description, a long thinking task and a long output with the full Claude Code tool list
- [x] #2 Both models run the set in Claude Code through the router with the same settings; pass or fail per task, tool-call failures and tok/s are recorded
- [x] #3 The long-thinking loop and the many-tools slowdown are each confirmed or ruled out on Qwen3.8
- [x] #4 Results and a recommendation are in doc-002, and the user decides whether Qwen3.8 replaces Qwen3.6
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Write the task set into bench/quality/ (PRD deliverable 6), so it can be re-run: a prompt, a fixture and a grader per task. T1 ts-demo edit (the TASK-033 prompt). T2 longer multi-step edit on ts-demo (new module, wiring into 3 files, a rename across the code base, tests). T3 code review of the real TASK-033 diff with 3 seeded bugs. T4 PR description for the real TASK-033 diff. T5 long thinking: a logic puzzle with one verified answer, no tools. T6 long output (a 400+ line module) with Claude Code's full tool list, plus T6c, the same with a short --tools list as the control. Graders: hidden tests for T1, T2 and T6; seeded bugs found for T3; a written rubric for T4; the exact answer for T5.
2. Runner bench/quality/run.ps1: a fresh fixture copy per run, claude -p through the router with the repo's claude-settings.json, stream-json and debug log, then the grader. Per-request tok/s, prompt and cached tokens come from llama-swap /api/metrics/activity.
3. Check how Claude Code's thinking reaches llama-server for both models, so T5 really exercises thinking.
4. Review gate: the user reviews the task set before the full run.
5. Run every task twice on local-coder-q6 and local-coder-38 (same 160K window, 2 slots, same client settings). Record pass/fail, tool-call failures, tok/s and time.
6. Long-thinking loop: thinking length, whether it ends, repetition (T5, plus any run that ends without an answer). Many-tools slowdown: T6 vs T6c tok/s and vs the TASK-033 raw bench.
7. Results and a recommendation in doc-002; the user decides.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Task set written to bench/quality/ (README.md with the task table and the t3/t4 rubrics, prompts/, fixtures/, graders/, run.ps1, run-all.ps1).
Findings while building it: LiteLLM sends Claude Code's requests to llama-swap as /v1/responses and drops the thinking/effort parameters, so both models think at their template default (Qwen3.8: xhigh); the reasoning comes back in the response but is not passed on to Claude Code, so the user sees nothing while the model thinks (a likely source of the lag spikes the user saw from the Mac on 2026-10-22). Per-request tokens, tok/s and draft counts come from llama-swap /api/metrics/activity; the reasoning from /api/captures.
Smoke runs on local-coder-38 (D:\local-ai\scratch\quality\smoke): t1 pass in 55 s (hidden tests 5/5, own 7/7, 118.8 tok/s, acceptance 0.86, 0 tool errors); t5 pass in 58 s (5/5 desks, one request of 7,376 output tokens, about 57 s with no visible output, 133.6 tok/s).
Side finding: llama-swap gives ports in alphabetical model order, so local-coder-38 runs on 10002 and local-coder-q6 on 10003; the port comments in ai-up.ps1 and the ai-down labels (TASK-033) name them the other way round. Both ports are checked and stopped, so behaviour is unaffected.
Waiting for the user to review the task set before the full run.

User review 2026-10-22: task set OK as is; lag spikes left until the OpenCode trial (TASK-035); fix the port labels; go for the full run.
Port fix: ai-up comment, ai-down labels and README now say 10002 local-coder-38, 10003 local-coder-q6 (llama-swap orders by model name). control-service.py MODEL_PORTS had the same mix-up, a real bug since TASK-033: the status showed local-coder-q6 while Qwen3.8 was loaded and nothing while Q6 was. Fixed and the control service restarted (Stop, then the scheduled task).
Full run started: run-all.ps1, 2 models x 7 tasks x 2 runs, output in D:\local-ai\scratch\quality\runs.

Full run done 2026-10-22 (28 runs, D:\local-ai\scratch\quality\runs\results.jsonl). t3/t4 graded by hand against the README rubrics. Qwen3.6 Q6_K 13/14 in 32 min, tool-call failures 33/171 (19%, mostly wrong-path Read); Qwen3.8 13/14 in 76 min, 4/182 (2.2%). Qwen3.8 thinks at xhigh: 5 requests hit Claude Code's 32K output cap, 4 of them drafting whole files in the reasoning, 1 a degenerate loop (t3 run 2, 41K chars of repeated \n); in t3 run 1 its reasoning leaked into the answer after it quoted the template's think tags. Many-tools slowdown: about 7% on Qwen3.8 (106 vs 115 tok/s on long answers), 3% on Qwen3.6, not material. Results, tables and the recommendation are in doc-002, section 'Quality check: Qwen3.8 vs Qwen3.6 (TASK-034, m-4)'; the TASK-033 port note there is corrected. Waiting for the user's decision (AC #4).

User decision 2026-10-22: go with the recommendation. Qwen3.8 replaces Qwen3.6 in TASK-036, with a lower default reasoning_effort in the llama-swap entry, after a re-run of t1-t3 and t6 at that effort confirms the quality.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added a re-runnable quality set in bench/quality/ (seven tasks with fixtures, hidden tests, rubrics, run.ps1 and run-all.ps1) and ran it twice per model in Claude Code through the router. Qwen3.8 + MTP and Qwen3.6 Q6_K both passed 13/14. Qwen3.8 passes the R4 tool-call gate (2.2% failures against 19%) and generates about twice as fast, but at its default xhigh thinking the long tasks took 2-3 times longer: 5 requests hit the 32K output cap, one of them a confirmed degenerate loop (rare, while reviewing a chat template). The many-tools slowdown is about 7%, not material. LiteLLM drops Claude Code's thinking/effort settings and hides the reasoning, a likely cause of the lag spikes seen from the Mac. Also fixed: llama-swap gives ports alphabetically, so the ai-up/ai-down/README port labels and the control service's port map (which named the wrong loaded model since TASK-033) were corrected. User decision: Qwen3.8 replaces Qwen3.6 in TASK-036 with a lower reasoning_effort, after a re-run of t1-t3 and t6 at that effort. Details in doc-002.
<!-- SECTION:FINAL_SUMMARY:END -->
