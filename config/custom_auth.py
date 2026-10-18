"""Router auth without a database: the x-litellm-api-key (or Authorization) bearer must equal
the master key. LiteLLM's built-in path looks other keys up in a database, which this setup
does not have, and answers 400 ("No connected db") for a wrong key. See backlog TASK-011."""
import hmac
import os

from fastapi import Request
from litellm.proxy._types import LitellmUserRoles, ProxyException, UserAPIKeyAuth


def _bearer(value: str) -> str:
    value = value.strip()
    return value[7:].strip() if value.lower().startswith("bearer ") else value


async def user_api_key_auth(request: Request, api_key: str) -> UserAPIKeyAuth:
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
