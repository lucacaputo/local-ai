# Quality set for local models (TASK-034)

A small version of the PRD bake-off (section 6): the same tasks, run in Claude Code (or OpenCode, TASK-035) through the router, on each local
model. Used to decide whether Qwen3.8 (`local-coder-38`) replaces Qwen3.6 (`local-coder-q6`).

## Tasks

| Id | Task | Fixture | Tools | Pass when |
|---|---|---|---|---|
| t1 | ts-demo edit: discount field and `Cart.count()`, with tests | `ts-demo` | full list | own tests pass (more than the 2 already there), hidden tests `graders/t1.hidden.test.ts` pass |
| t2 | Longer multi-step edit: rename across the code base, a coupon module wired into cart and report, tests | `ts-demo` | full list | own tests pass, hidden tests `graders/t2.hidden.test.ts` pass, no `calcTotal` left in `cart.ts` / `report.ts` |
| t3 | Code review of the real TASK-033 diff with 3 seeded bugs | `review-033` | full list | rubric below: at least 2 of the 3 seeded bugs found |
| t4 | PR description of the real TASK-033 diff, saved as `PR.md` | `pr-033` | full list | rubric below |
| t5 | Long thinking: a 5x5 logic puzzle, no tools | `ts-demo` (unused) | none | all 5 desk lines match `graders/t5.expected.txt` (`graders/t5-puzzle-check.py` proves the solution is unique) |
| t6 | Long output: a ~400-line module and 30+ tests, each file in one Write call | `ts-demo` | full list | own tests pass, 30+ tests in `test/inventory.test.ts`, `src/inventory.ts` 300+ lines |
| t6c | t6 with a short tool list (`Read,Edit,Write,Glob,Grep,PowerShell`) | `ts-demo` | short | as t6; the control for the many-tools slowdown (compare `tg_long` with t6) |

"Full list" is Claude Code's default tool list. Every task allows the same tools without asking:
`Read,Edit,Write,Glob,Grep,PowerShell` with `--permission-mode acceptEdits`.

### t3 rubric

The seeded bugs (the real change, commit 0d58c22, has none of them):

1. `scripts/ai-up.ps1`: `$env:LOCAL_AI_REPO = $root` instead of `$repo`, so llama-swap looks for the chat template in
   the models folder and `local-coder-38` does not start.
2. `scripts/ai-up.ps1`: `elseif ($free -gt $Q38MinFreeVramMiB)`, so the low-VRAM warning shows when there is enough
   VRAM and stays quiet when there is not.
3. `config/litellm.yaml`: `local-coder-38` routes to `openai/local-coder-q6`, so picking Local Coder 3.8 serves Qwen3.6.

Pass: at least 2 of the 3, each named with its file. Also record the claims that are wrong (false positives) and
whether the model edited files although told not to.

### t4 rubric

Key points, each counts when it is stated correctly:

1. A new trial model entry `local-coder-38` (Qwen3.8 27B UD-Q6_K) in llama-swap, LiteLLM and the Claude Code model picker.
2. MTP speculative decoding (`--spec-type draft-mtp`, draft 3) and the measured speed-up stated in the config comment.
3. The patched chat template and why: a later system message raised an error.
4. `LOCAL_AI_REPO`, set by `ai-up`, so llama-swap finds the template in the repo.
5. `ai-up` / `ai-down`: the port 10003 check and stop, and the low-VRAM warning; `versions.psd1` with the download and hash.

Pass: `PR.md` exists, a title of at most 72 characters, at least 4 of the 5 points, and no invented facts (tests,
benchmarks or files that the diff does not show).

## Running

Start the stack (`scripts\ai-up.ps1`), then from the PC:

```powershell
bench\quality\run-all.ps1                          # both models, every task, 2 runs each
bench\quality\run.ps1 -Model local-coder-38 -Task t2 -Rep 3
bench\quality\run-all.ps1 -Client opencode -Models local-coder-38   # the same set in OpenCode (TASK-035), runs named oc-*
bench\quality\run.ps1 -Model local-coder-38 -Task t6 -Client opencode -ClientConfig <opencode.json> -Tag ctx82k
```

`-ClientConfig` replaces `config\claude-settings.json` or `config\opencode.json` for one run (a smaller window for a
compaction test, for example); `-Tag` goes into the run name. `-Models` takes a list only when run-all is called from
PowerShell: through `powershell -File` a comma list arrives as one string, so call it once per model there.

Each run works in a fresh copy of its fixture under `-Out` (default `D:\local-ai\scratch\quality\runs`) and keeps
its data next to it in `<run>.data`, out of the model's sight: `stream.jsonl` (Claude Code), `answer.md` (the final
text), `activity.json` (llama-swap per-request tokens, speed and draft counts) and `resp-<id>.txt` (the server's
responses, including the reasoning). One summary line per run goes to `<Out>\results.jsonl`.

Notes:

- LiteLLM drops Claude Code's `thinking` and effort settings on the way to llama.cpp, so both models think at their
  template's default effort (Qwen3.8: xhigh). The reasoning is not shown in Claude Code; `reasoning_chars` in the
  results counts it from the captured responses.
- `tg` is output tokens over generation time for all requests of a run; `tg_long` only for requests with 2,000+
  output tokens.
- OpenCode (`-Client opencode`): `opencode run --format json --auto` with `config\opencode.json` through the router,
  web access denied, no tools for t5; t6c is skipped. `tool_errors` counts failed tools and calls OpenCode could not
  parse (tool `invalid`); Claude Code's count also includes failed test runs. `compactions` counts Claude Code's
  `compact_boundary` events and OpenCode's resume text after a compaction.
- t3 and Qwen3.8: when the model quotes the chat template in the fixture it writes its own control tokens, and
  `<|im_end|>` ends the generation; in OpenCode that left an empty answer in all four runs (TASK-035).
