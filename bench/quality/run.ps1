# TASK-034 quality set: one run of one task on one model, through the router as scripts\claude-local.ps1 runs it.
# A fresh copy of the task's fixture, claude -p with the repo's claude-settings.json (or, with -Client opencode,
# opencode run with config\opencode.json, TASK-035), then the grader. Per-request tokens, speed and draft acceptance
# come from llama-swap /api/metrics/activity, and the hidden reasoning from /api/captures (LiteLLM does not pass it
# on to Claude Code).
#
#   bench\quality\run.ps1 -Model local-coder -Task t1 [-Rep 1] [-Client opencode] [-Out D:\local-ai\scratch\quality\runs]
#   bench\quality\run.ps1 -Model local-coder -Task t6 -Client opencode -ClientConfig <opencode.json> -Tag ctx82k   (compaction test)
#
# Needs the stack up (scripts\ai-up.ps1). Appends one line per run to <Out>\results.jsonl.
param(
  [Parameter(Mandatory)][string]$Model,
  [Parameter(Mandatory)][ValidateSet('t1', 't2', 't3', 't4', 't5', 't6', 't6c')][string]$Task,
  [int]$Rep = 1,
  [string]$Out = 'D:\local-ai\scratch\quality\runs',
  [int]$TimeoutMin = 40,
  [ValidateSet('claude', 'opencode')][string]$Client = 'claude',
  [string]$ClientConfig,   # instead of config\claude-settings.json / config\opencode.json, e.g. a smaller window
  [string]$Tag              # added to the run name
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. "$repo\scripts\lib\secrets.ps1"
$swap = 'http://127.0.0.1:8080'

# fixture, prompt, tool list (null = Claude Code's full default list)
$short = 'Read,Edit,Write,Glob,Grep,PowerShell'
$tasks = @{
  t1  = @{ Fixture = 'ts-demo';    Prompt = 't1-ts-edit.txt';     Tools = $null }
  t2  = @{ Fixture = 'ts-demo';    Prompt = 't2-multi-edit.txt';  Tools = $null }
  t3  = @{ Fixture = 'review-033'; Prompt = 't3-review.txt';      Tools = $null }
  t4  = @{ Fixture = 'pr-033';     Prompt = 't4-pr.txt';          Tools = $null }
  t5  = @{ Fixture = 'ts-demo';    Prompt = 't5-puzzle.txt';      Tools = '' }
  t6  = @{ Fixture = 'ts-demo';    Prompt = 't6-long-output.txt'; Tools = $null }
  t6c = @{ Fixture = 'ts-demo';    Prompt = 't6-long-output.txt'; Tools = $short }   # control for the many-tools slowdown
}
$t = $tasks[$Task]
$name = (@($(if ($Client -eq 'opencode') { 'oc' }), $Model, $Task, $Tag, "r$Rep") | Where-Object { $_ }) -join '-'
if ($Client -eq 'opencode' -and $Task -eq 't6c') { throw 't6c is the short-tool-list control for Claude Code; OpenCode has a short list already' }
$dir = Join-Path $Out $name
if (Test-Path $dir) { throw "$dir exists; pick another -Rep or remove it" }
New-Item -ItemType Directory -Force $Out | Out-Null
Copy-Item -Recurse (Join-Path $PSScriptRoot "fixtures\$($t.Fixture)") $dir
$data = "$dir.data"   # outside the work folder, so the model cannot see it
New-Item -ItemType Directory $data | Out-Null

$before = @((Invoke-RestMethod "$swap/api/metrics/activity?limit=1").data | ForEach-Object id)
$firstId = if ($before) { [int]$before[0] } else { 0 }

if ($Client -eq 'opencode') {
  $env:OPENCODE_CONFIG = if ($ClientConfig) { $ClientConfig } else { "$repo\config\opencode.json" }
  $env:LOCAL_AI_ROUTER_URL = 'http://127.0.0.1:4000'
  $env:LOCAL_AI_ROUTER_KEY = Get-LocalAiRouterKey
  # --auto approves what is not denied; web access is denied as in the Claude Code runs. t5 gets no tools at all.
  $env:OPENCODE_PERMISSION = '{"webfetch":"deny"}'
  $env:OPENCODE_CONFIG_CONTENT = if ($Task -eq 't5') {
    '{"tools":{"bash":false,"edit":false,"glob":false,"grep":false,"read":false,"skill":false,"task":false,"todowrite":false,"webfetch":false,"write":false}}'
  } else { '{}' }
  $exe = (Get-Command opencode.cmd).Source -replace 'opencode\.cmd$', 'node_modules\opencode-ai\bin\opencode.exe'
  $cliArgs = @('run', '--format', 'json', '--auto', '--model', "local-ai/$Model", '--title', $name)   # a title, so no title request
} else {
  $env:ANTHROPIC_BASE_URL = 'http://127.0.0.1:4000'
  $env:ANTHROPIC_CUSTOM_HEADERS = "x-litellm-api-key: Bearer $(Get-LocalAiRouterKey)"
  $exe = (Get-Command claude).Source
  $settings = if ($ClientConfig) { $ClientConfig } else { "$repo\config\claude-settings.json" }
  $cliArgs = @('--settings', "`"$settings`"", '-p', '--model', $Model, '--permission-mode', 'acceptEdits',
               '--allowedTools', $short, '--output-format', 'stream-json', '--verbose', '--max-turns', '80',
               '--debug-file', "`"$data\debug.txt`"")
  if ($null -ne $t.Tools) { $cliArgs += @('--tools', "`"$($t.Tools)`"") }
}
$sw = [Diagnostics.Stopwatch]::StartNew()
$p = Start-Process $exe -ArgumentList $cliArgs -WorkingDirectory $dir -PassThru -WindowStyle Hidden `
       -RedirectStandardInput (Join-Path $PSScriptRoot "prompts\$($t.Prompt)") `
       -RedirectStandardOutput "$data\stream.jsonl" -RedirectStandardError "$data\stderr.txt"
$null = $p.Handle   # without it ExitCode stays empty
$timedOut = -not $p.WaitForExit($TimeoutMin * 60000)
if ($timedOut) { Stop-Process -Id $p.Id -Force }
$secs = [math]::Round($sw.Elapsed.TotalSeconds)

# the client's side: turns, tool calls, tool errors, final text
$lines = @(Get-Content "$data\stream.jsonl" -Encoding UTF8 | ForEach-Object { $_.TrimStart([char]0xFEFF) } | Where-Object { $_.StartsWith('{') } | ForEach-Object { $_ | ConvertFrom-Json })
if ($Client -eq 'opencode') {
  # events: step_start / tool_use / text / step_finish (a step is one request); a failed tool has state.status error,
  # a call OpenCode could not parse (broken JSON) comes as tool "invalid" with status completed
  $toolUses = @($lines | Where-Object type -eq 'tool_use')
  $toolErrors = @($toolUses | Where-Object { $_.part.state.status -eq 'error' -or $_.part.tool -eq 'invalid' })
  # after a compaction OpenCode adds this synthetic user text to resume the work
  $compactions = @($lines | Where-Object { $_.type -eq 'text' -and $_.part.text -like 'Continue if you have next steps*' }).Count
  $steps = @($lines | Where-Object type -eq 'step_finish')
  $lastMsg = ($lines | Where-Object type -eq 'text' | Select-Object -Last 1).part.messageID
  $final = [pscustomobject]@{ result = (($lines | Where-Object { $_.type -eq 'text' -and $_.part.messageID -eq $lastMsg } | ForEach-Object { $_.part.text }) -join "`n")
                              is_error = [bool]($lines | Where-Object type -eq 'error'); num_turns = $steps.Count }
} else {
  $toolUses = @($lines | Where-Object type -eq 'assistant' | ForEach-Object { $_.message.content } | Where-Object type -eq 'tool_use')
  $toolErrors = @($lines | Where-Object type -eq 'user' | ForEach-Object { $_.message.content } | Where-Object { $_.type -eq 'tool_result' -and $_.is_error })
  $final = $lines | Where-Object type -eq 'result' | Select-Object -Last 1
  $compactions = @($lines | Where-Object { $_.type -eq 'system' -and $_.subtype -eq 'compact_boundary' }).Count
}
[IO.File]::WriteAllText("$data\answer.md", [string]$final.result)

# server side: per-request tokens and timings
$reqs = @((Invoke-RestMethod "$swap/api/metrics/activity?limit=500").data | Where-Object { $_.id -gt $firstId -and $_.model -eq $Model } | Sort-Object id)
$reqs | ConvertTo-Json -Depth 5 | Set-Content "$data\activity.json"
$reasoningChars = 0; $maxReasoning = 0
foreach ($r in $reqs) {
  if (-not $r.has_capture) { continue }
  $c = Invoke-RestMethod "$swap/api/captures/$($r.id)"
  $body = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($c.resp_body))
  [IO.File]::WriteAllText("$data\resp-$($r.id).txt", $body)
  # streamed responses carry the reasoning as response.reasoning_text.delta events (/v1/responses, Claude Code) or as
  # reasoning_content deltas (/v1/chat/completions, OpenCode)
  $n = 0
  foreach ($m in [regex]::Matches($body, '"type":"response\.reasoning_text\.delta"[^\n]*?"delta":"((?:[^"\\]|\\.)*)"')) { $n += $m.Groups[1].Value.Length }
  foreach ($m in [regex]::Matches($body, '"reasoning_content":"((?:[^"\\]|\\.)*)"')) { $n += $m.Groups[1].Value.Length }
  $reasoningChars += $n; $maxReasoning = [math]::Max($maxReasoning, $n)
}
# activity: input_tokens are the uncached prompt tokens, cache_tokens the reused ones
$tok = @($reqs | ForEach-Object { $_.tokens })
function Rate($xs) {   # output tokens over generation time
  $xs = @($xs | Where-Object { $_.tokens_per_second -gt 0 }); $ms = ($xs | ForEach-Object { $_.output_tokens / $_.tokens_per_second } | Measure-Object -Sum).Sum
  if ($ms) { [math]::Round(($xs | ForEach-Object { $_.output_tokens } | Measure-Object -Sum).Sum / $ms, 1) } else { $null }
}
function Sum($xs, $f) { ($xs | ForEach-Object { $_.$f } | Where-Object { $_ -gt 0 } | Measure-Object -Sum).Sum }
$long = @($tok | Where-Object { $_.output_tokens -ge 2000 })   # long answers: where the many-tools slowdown would show

# grader
Push-Location $dir
function TestCounts([string]$text) {   # node --test prints a TAP summary when its output is not a terminal
  $n = { param($k) $m = [regex]::Match($text, "# $k (\d+)"); if ($m.Success) { [int]$m.Groups[1].Value } else { 0 } }
  @{ pass = (& $n 'pass'); fail = (& $n 'fail') }
}
$grade = @{}
$ErrorActionPreference = 'Continue'
switch ($Task) {
  { $_ -in 't1', 't2' } {
    $own = TestCounts ((& npm.cmd test 2>&1) -join "`n")
    New-Item -ItemType Directory hidden | Out-Null
    Copy-Item (Join-Path $PSScriptRoot "graders\$Task.hidden.test.ts") hidden\
    $hid = TestCounts ((& node --test 'hidden/*.test.ts' 2>&1) -join "`n")
    $grade = @{ own_pass = $own.pass; own_fail = $own.fail; hidden_pass = $hid.pass; hidden_fail = $hid.fail }
    $ok = $own.pass -gt 2 -and $own.fail -eq 0 -and $hid.fail -eq 0 -and $hid.pass -gt 0
    if ($Task -eq 't2') {   # the rename reached the callers
      $left = @(Select-String -Path src\cart.ts, src\report.ts -Pattern 'calcTotal').Count
      $grade.calcTotal_left_in_callers = $left; $ok = $ok -and $left -eq 0
    }
    $grade.pass = $ok
  }
  { $_ -in 't6', 't6c' } {
    $own = TestCounts ((& npm.cmd test 2>&1) -join "`n")
    $inv = TestCounts ((& node --test test/inventory.test.ts 2>&1) -join "`n")
    $lines6 = if (Test-Path src\inventory.ts) { @(Get-Content src\inventory.ts).Count } else { 0 }
    $grade = @{ own_pass = $own.pass; own_fail = $own.fail; inventory_tests = $inv.pass; inventory_lines = $lines6 }
    $grade.pass = $own.fail -eq 0 -and $inv.pass -ge 30 -and $inv.fail -eq 0 -and $lines6 -ge 300
  }
  't5' {
    $want = @(Get-Content (Join-Path $PSScriptRoot 'graders\t5.expected.txt') | ForEach-Object { ($_ -replace '\s+', ' ').Trim().ToLower() })
    $got = @(([string]$final.result) -split "`n" | Where-Object { $_ -match '^\W*DESK \d' } | ForEach-Object { ($_ -replace '[*`]', '' -replace '\s+', ' ').Trim().ToLower() } | Select-Object -Last 5)
    $grade = @{ desks_right = @(0..4 | Where-Object { $_ -lt $got.Count -and $got[$_] -eq $want[$_] }).Count }
    $grade.pass = $grade.desks_right -eq 5
  }
  default { $grade = @{ pass = 'manual'; pr_md = (Test-Path PR.md) } }   # t3, t4: rubric in README.md
}
Pop-Location
$ErrorActionPreference = 'Stop'

$res = [ordered]@{
  run = $name; client = $Client; model = $Model; task = $Task; rep = $Rep; tag = $Tag; client_config = $ClientConfig; at = (Get-Date).ToString('s'); secs = $secs; timed_out = $timedOut
  exit = $p.ExitCode; claude_error = [bool]$final.is_error; turns = $final.num_turns
  tool_calls = $toolUses.Count; tool_errors = $toolErrors.Count; compactions = $compactions
  first_prompt_tokens = if ($tok) { $tok[0].input_tokens + [math]::Max(0, $tok[0].cache_tokens) } else { $null }
  requests = $reqs.Count; output_tokens = (Sum $tok 'output_tokens'); max_output_tokens = ($tok | ForEach-Object { $_.output_tokens } | Measure-Object -Maximum).Maximum
  uncached_prompt_tokens = (Sum $tok 'input_tokens'); max_prompt_tokens = ($tok | ForEach-Object { $_.input_tokens + [math]::Max(0, $_.cache_tokens) } | Measure-Object -Maximum).Maximum
  max_request_secs = [math]::Round((($reqs | ForEach-Object { $_.duration_ms } | Measure-Object -Maximum).Maximum) / 1000, 1)
  tg = (Rate $tok); tg_long = (Rate $long)
  acceptance = if (Sum $tok 'draft_tokens') { [math]::Round((Sum $tok 'draft_acc_tokens') / (Sum $tok 'draft_tokens'), 2) } else { $null }
  reasoning_chars = $reasoningChars; max_reasoning_chars = $maxReasoning
  grade = $grade
}
$json = $res | ConvertTo-Json -Compress -Depth 4
Add-Content (Join-Path $Out 'results.jsonl') $json
$json
