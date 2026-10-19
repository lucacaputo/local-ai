"""Router auth without a database. A request is let in when
- tailscale serve forwarded it from a Tailscale login on the allowlist: serve sets the
  Tailscale-User-Login header and overwrites one sent by the client (TASK-022, TASK-023), or
- its x-litellm-api-key (or Authorization) bearer equals the master key (TASK-011).
LiteLLM's built-in path looks other keys up in a database, which this setup does not have, and
answers 400 ("No connected db") for a wrong key. Programs on the PC can reach the loopback port
and set the identity header themselves; the user accepted that (TASK-022).

Clients that come in by identity still send x-litellm-api-key, with the fixed non-secret value
"tailscale-identity": LiteLLM forwards the Claude subscription token (Authorization) to Anthropic
only when that header is present, whatever its value. The value itself never lets a request in."""
import hmac
import os

from fastapi import Request
from litellm.proxy._types import LitellmUserRoles, ProxyException, UserAPIKeyAuth

# Comma-separated, injected by scripts\start-litellm.ps1; empty means key-only.
_ALLOWED_LOGINS = frozenset(
    login.strip().lower() for login in os.environ.get("LOCAL_AI_ALLOWED_LOGINS", "").split(",") if login.strip()
)


def _bearer(value: str) -> str:
    value = value.strip()
    return value[7:].strip() if value.lower().startswith("bearer ") else value


async def user_api_key_auth(request: Request, api_key: str) -> UserAPIKeyAuth:
    login = request.headers.get("tailscale-user-login", "").strip().lower()
    if login and login in _ALLOWED_LOGINS:
        return UserAPIKeyAuth(api_key="tailscale-identity", user_id=login, user_role=LitellmUserRoles.PROXY_ADMIN)
    master = os.environ.get("LITELLM_MASTER_KEY", "")
    candidates = [request.headers.get("x-litellm-api-key", ""), api_key or ""]
    if master and any(c and hmac.compare_digest(_bearer(c), master) for c in candidates):
        return UserAPIKeyAuth(api_key="master", user_role=LitellmUserRoles.PROXY_ADMIN)
    raise ProxyException(
        message="Authentication Error: missing or invalid router key",
        type="auth_error",
        param="x-litellm-api-key",
        code=401,
    )
