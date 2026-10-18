# Environment for a Claude Code session that uses the local AI router.
# Template only: no secrets here. Copy the values into the launcher (ai-up / claude wrapper).
#
# Do NOT set ANTHROPIC_API_KEY or ANTHROPIC_AUTH_TOKEN: either one replaces the
# subscription login and switches Claude requests to API billing.
$env:ANTHROPIC_BASE_URL       = 'http://127.0.0.1:4000'   # router; use the tailnet address from remote devices
$env:ANTHROPIC_CUSTOM_HEADERS = "x-litellm-api-key: Bearer $LocalKey"   # $LocalKey comes from the secret store (TASK-006)

# Launch with the picker rows and the local context window (see claude-settings.json):
#   claude --settings <repo>\config\claude-settings.json
# or merge claude-settings.json into the user settings.json on that machine.
# CLAUDE_CODE_MAX_CONTEXT_TOKENS must match llama-server -c (131072).
