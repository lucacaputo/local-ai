# Starts the local AI stack: llama-swap (model loads on first use) and the LiteLLM router, both on
# loopback, secrets injected from Credential Manager, then publishes the router on the tailnet.
# Nothing is started at boot; run scripts\ai-down.ps1 to stop everything and free the GPU.
#
#   scripts\ai-up.ps1 [-Warm] [-NoTailnet] [-Force]
#     -Warm       load the model now instead of on the first request
#     -NoTailnet  do not publish port 4000 on the tailnet
#     -Force      start even if a game or other GPU work seems to be running
param(
  [switch]$Warm,
  [switch]$NoTailnet,
  [switch]$Force,
  [int]$MinFreeVramMiB = 22000,                 # model + 128K KV cache need about 21.6 GB (decision-004)
  [int]$Q6MinFreeVramMiB = 28500,               # local-coder-q6 at 160K holds 27.7 GB (TASK-020): warn below this
  [int]$Q38MinFreeVramMiB = 30200,              # local-coder-38 at 160K with MTP and 2 slots holds 29.4 GB (TASK-033)
  [string]$GamePathPattern                      # override of the game-detection pattern (for tests)
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\secrets.ps1"
. "$PSScriptRoot\lib\stack.ps1"
$clock = [Diagnostics.Stopwatch]::StartNew()
$root = Get-AiRoot
$repo = Split-Path $PSScriptRoot -Parent
$swapExe = Join-Path $root 'bin\llama-swap-v265\llama-swap.exe'
$swapUrl = 'http://127.0.0.1:8080'
$routerUrl = 'http://127.0.0.1:4000'

# 1. installed?
foreach ($need in @($swapExe, (Join-Path $root 'bin\llama.cpp-b11719\llama-server.exe'), (Join-Path $root 'litellm-venv\Scripts\litellm.exe'), (Join-Path $root 'models\Qwen3.6-27B-Q4_K_M.gguf'), (Join-Path $root 'models\Qwen3.6-27B-Q6_K.gguf'))) {
  if (-not (Test-Path $need)) { throw "Missing $need. Run scripts\install.ps1 first." }
}
if (-not (Get-LocalAiSecret)) { throw 'No router key yet. Run scripts\init-secrets.ps1 first.' }
$key = Get-LocalAiRouterKey
$auth = @{ 'x-litellm-api-key' = "Bearer $key" }

# 2. already up? (no duplicates)
$swapUp = Test-Http "$swapUrl/health"
$routerUp = Test-Http "$routerUrl/health/liveliness"
if ($swapUp -and $routerUp) {
  "Stack is already running (llama-swap $swapUrl, router $routerUrl). Nothing started."
  return
}
# llama-swap gives each model its own llama-server port from startPort: 10001 local-coder, 10002 local-coder-q6,
# 10003 local-coder-38 (TASK-033 trial)
if ($swapUp -or $routerUp -or (Get-Listener 8080) -or (Get-Listener 4000) -or (Get-Listener 10001) -or (Get-Listener 10002) -or (Get-Listener 10003)) {
  throw 'The stack is only partly running or a port is taken. Run scripts\ai-down.ps1, then start again.'
}

# 3. guard: do not start on top of a game or other heavy GPU work
$free = Get-VramFreeMiB
if (-not $Force) {
  $games = if ($GamePathPattern) { Find-GameProcesses $GamePathPattern } else { Find-GameProcesses }
  $why = @()
  if ($games) { $why += "game process running: $($games -join ', ')" }
  if ($free -lt $MinFreeVramMiB) { $why += "only $free MiB of VRAM free, the model needs about $MinFreeVramMiB MiB" }
  if ($why) { throw ("Not starting: " + ($why -join '; ') + ". Close the game or free the GPU, then try again (at the PC, -Force starts anyway).") }
}
# the Q6_K entry is optional: low VRAM only rules it out, so warn instead of refusing
if ($free -lt $Q6MinFreeVramMiB) {
  Write-Warning "Only $free MiB of VRAM free: enough for local-coder, not for local-coder-q6 (about $Q6MinFreeVramMiB MiB). Free GPU memory before picking Local Coder Q6."
} elseif ($free -lt $Q38MinFreeVramMiB) {
  Write-Warning "Only $free MiB of VRAM free: not enough for local-coder-38 (about $Q38MinFreeVramMiB MiB). Free GPU memory before picking Local Coder 3.8."
}

# 4. start
$baseline = Get-VramUsedMiB
New-Item -ItemType Directory -Force (Join-Path $root 'logs'), (Join-Path $root 'run') | Out-Null
$env:LOCAL_AI_ROOT = $root
$env:LOCAL_AI_REPO = $repo   # config\llama-swap.yaml reads chat templates from the repo's config folder
try {
  Start-Detached $swapExe @('-config', (Join-Path $repo 'config\llama-swap.yaml'), '-listen', '127.0.0.1:8080') `
    (Join-Path $root 'logs\llama-swap.out.log') (Join-Path $root 'logs\llama-swap.err.log') | Out-Null
  for ($i = 0; $i -lt 60 -and -not (Test-Http "$swapUrl/health"); $i++) { Start-Sleep 1 }
  if (-not (Test-Http "$swapUrl/health")) { throw "llama-swap did not become healthy; see $root\logs\llama-swap.err.log" }
  & "$PSScriptRoot\start-litellm.ps1" -Root $root | Out-Null
  if (-not (Test-Http "$routerUrl/v1/models" $auth 10)) { throw 'Router is up but rejects the stored key on /v1/models.' }
} catch {
  Write-Warning "Start failed: $($_.Exception.Message) - cleaning up."
  & "$PSScriptRoot\ai-down.ps1" | Out-Null
  throw
}

# 5. tailnet: the "/" route of port 4000 in HTTP mode, so tailscale serve tells the router who is calling
# (TASK-022, TASK-023). Other routes on the port (the control service) are not ours to touch.
$tailnet = ''
if (-not $NoTailnet) {
  $ts = Get-TailscaleExe
  if ((Test-Path $ts) -and ((Invoke-Quiet $ts @('status')) -notmatch 'Logged out|stopped')) {
    if ((Get-Serve4000).Mode -eq 'tcp') { Invoke-Quiet $ts @('serve', '--tcp=4000', 'off') | Out-Null }   # TCP and HTTP cannot share the port
    Invoke-Quiet $ts @('serve', '--bg', '--http', '4000', 'http://127.0.0.1:4000') | Out-Null
    $tailnet = "tailnet http://$(Get-TailnetName):4000"
  } else { Write-Warning 'Tailscale is not signed in; the router is not published on the tailnet.' }
}

# 6. optional warm-up
if ($Warm) {
  $w = [Diagnostics.Stopwatch]::StartNew()
  $b = @{ model = 'local-coder'; max_tokens = 5; messages = @(@{ role = 'user'; content = 'hi' }) } | ConvertTo-Json -Depth 5
  Invoke-RestMethod "$routerUrl/v1/chat/completions" -Method Post -ContentType 'application/json' -Headers $auth -Body $b -TimeoutSec 300 | Out-Null
  "Model loaded in $([math]::Round($w.Elapsed.TotalSeconds, 1)) s."
}

@{ startedAt = (Get-Date).ToString('o'); vramBaselineMiB = $baseline; llamaSwapPid = (Get-Listener 8080).Pid } | ConvertTo-Json | Set-Content (Get-StateFile $root)
"Stack healthy in $([math]::Round($clock.Elapsed.TotalSeconds, 1)) s: llama-swap $swapUrl, router $routerUrl$(if ($tailnet) { ", $tailnet" }). The model loads on the first request$(if ($Warm) { ' (already loaded)' })."
"Use: scripts\claude-local.ps1   Stop: scripts\ai-down.ps1"
