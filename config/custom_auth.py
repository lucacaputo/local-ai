"""Router auth without a database. A request is let in when
- tailscale serve forwarded it from a Tailscale login on the allowlist: serve sets the
  Tailscale-User-Login header and overwrites one sent by the client (TASK-022, TASK-023), or
- its x-litellm-api-key (or Authorization) bearer equals the master key (TASK-011).
LiteLLM's built-in path looks other keys up in a database, which this setup does not have, and
answers 400 ("No connected db") for a wrong key. Programs on the PC can reach the loopback port
and set the identity header themselves; the user accepted that (TASK-022).

Clients that come in by identity still send x-litellm-api-key, with the fixed non-secret value
"tailscale-identity": LiteLLM forwards the Claude subscription token (Authorization) to Anthropic
only when that header is present, whatever its value. The value itself never lets a request in.

tailscale serve also attaches the identity to requests made by web pages in the user's browser, and
LiteLLM answers cross-origin requests with Access-Control-Allow-Origin: *. Browsers send Origin (and
Sec-Fetch-Site) on such requests and Claude Code sends neither, so a request carrying either one is
not let in by identity, only by the key (TASK-031).

Agent sandboxes (TASK-042) reach the router only through their gate, which drops identity and forwarding
headers and marks each request with x-local-ai-sandbox. A sandbox has a key of its own: the router knows it by
its SHA-256 hash, in the JSON file named by LOCAL_AI_SANDBOX_KEYS ({"<user>": "<hex hash>"}, outside the repo,
read again whenever it changes, so revoking one sandbox needs no restart). A sandbox key may only list models and
ask a local model (local-*) for a chat completion; anything else, Claude models included, is refused with 403.
A marked request is let in by a sandbox key only: never by identity, never by the master key."""
import hashlib
import hmac
import json
import os

from fastapi import Request
from litellm.proxy._types import LitellmUserRoles, ProxyException, UserAPIKeyAuth
from litellm.proxy.auth.auth_utils import get_request_route
from litellm.proxy.common_utils.http_parsing_utils import read_request_body

# Comma-separated, injected by scripts\start-litellm.ps1; empty means key-only.
_ALLOWED_LOGINS = frozenset(
    login.strip().lower() for login in os.environ.get("LOCAL_AI_ALLOWED_LOGINS", "").split(",") if login.strip()
)


SANDBOX_MARK = "x-local-ai-sandbox"
_SANDBOX_ROUTES = frozenset({"/v1/chat/completions", "/chat/completions", "/v1/models", "/models"})
_LOCAL_PREFIX = "local-"
_keys_cache: dict = {"stamp": None, "keys": {}}


def _bearer(value: str) -> str:
    value = value.strip()
    return value[7:].strip() if value.lower().startswith("bearer ") else value


def _sandbox_keys() -> dict:
    """hash -> user; empty (no sandbox gets in) when the file is missing or unreadable."""
    path = os.environ.get("LOCAL_AI_SANDBOX_KEYS", "")
    try:
        st = os.stat(path) if path else None
    except OSError:
        st = None
    stamp = (st.st_mtime_ns, st.st_size) if st else None
    if stamp != _keys_cache["stamp"]:
        keys = {}
        if st:
            try:
                with open(path, encoding="utf-8-sig") as f:   # PowerShell 5.1 writes a BOM
                    keys = {str(h).strip().lower(): str(u) for u, h in json.load(f).items() if h}
            except (OSError, ValueError, AttributeError):
                keys = {}
        _keys_cache.update(stamp=stamp, keys=keys)
    return _keys_cache["keys"]


def _deny(message: str, code: int) -> ProxyException:
    return ProxyException(message=message, type="auth_error", param="x-litellm-api-key", code=code)


async def _sandbox_auth(request: Request, user: str) -> UserAPIKeyAuth:
    route = get_request_route(request)
    if route not in _SANDBOX_ROUTES:
        raise _deny(f"Sandbox key: route {route} is not allowed", 403)
    if route.endswith("/chat/completions"):
        model = str((await read_request_body(request)).get("model", ""))
        if not model.startswith(_LOCAL_PREFIX):
            raise _deny(f"Sandbox key: model {model or '(none)'} is not allowed, only local models", 403)
    return UserAPIKeyAuth(api_key=f"sandbox-{user}", user_id=f"sandbox-{user}", user_role=LitellmUserRoles.INTERNAL_USER)


async def user_api_key_auth(request: Request, api_key: str) -> UserAPIKeyAuth:
    candidates = [_bearer(c) for c in (request.headers.get("x-litellm-api-key", ""), api_key or "") if c]
    sandboxes = _sandbox_keys()
    for c in candidates:
        user = sandboxes.get(hashlib.sha256(c.encode()).hexdigest())
        if user:
            return await _sandbox_auth(request, user)
    if SANDBOX_MARK in request.headers:
        raise _deny("Authentication Error: missing or invalid sandbox key", 401)
    login = request.headers.get("tailscale-user-login", "").strip().lower()
    from_browser = "origin" in request.headers or "sec-fetch-site" in request.headers
    if login and login in _ALLOWED_LOGINS and not from_browser:
        return UserAPIKeyAuth(api_key="tailscale-identity", user_id=login, user_role=LitellmUserRoles.PROXY_ADMIN)
    master = os.environ.get("LITELLM_MASTER_KEY", "")
    if master and any(hmac.compare_digest(c, master) for c in candidates):
        return UserAPIKeyAuth(api_key="master", user_role=LitellmUserRoles.PROXY_ADMIN)
    raise _deny("Authentication Error: missing or invalid router key", 401)
