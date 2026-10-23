"""Control service: starts and stops the local AI stack on request, so it can be run from another device
(m-3, TASK-025). It only runs scripts\\ai-up.ps1 and scripts\\ai-down.ps1, without parameters; it never
starts the stack by itself and holds no GPU memory.

Listens on 127.0.0.1:4100. tailscale serve publishes it under /control on tailnet port 4000 and strips
that prefix (TASK-022). Routes:
  GET  /health  no auth; for the launcher's readiness check
  GET  /status  router, llama-swap, loaded model, VRAM, running action
  POST /up      runs ai-up.ps1 (game guard included)
  POST /down    runs ai-down.ps1
A request is let in only when tailscale serve forwarded it from a login on the router's allowlist
(Get-AllowedLogins in scripts\\lib\\stack.ps1, re-read on demand, see _allowed_logins) and it carries neither Origin nor
Sec-Fetch-Site, which browsers send and command-line clients do not (TASK-031). One up/down runs at a
time; a second one gets 409. Every request is logged to <root>\\logs\\control.log.

Usage: python control-service.py <root>      (started by scripts\\start-control.ps1)
"""
import json
import os
import socket
import subprocess
import sys
import threading
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST, PORT = "127.0.0.1", 4100
SCRIPTS = os.path.dirname(os.path.abspath(__file__))
ROOT = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("LOCAL_AI_ROOT", r"D:\local-ai")
LOG = os.path.join(ROOT, "logs", "control.log")
ALLOWED_TTL, ALLOWED_RETRY = 60, 5   # seconds between re-reads of the allowlist: while it has logins / while empty
MODEL_PORTS = {10001: "local-coder"}   # llama-server port from config\llama-swap.yaml (one model)

_action_lock = threading.Lock()
_running = None   # "up" / "down" while one runs
_log_lock = threading.Lock()
_allowed_lock = threading.Lock()
_initial = frozenset(x.strip().lower() for x in os.environ.get("LOCAL_AI_ALLOWED_LOGINS", "").split(",") if x.strip())
_allowed = {"logins": _initial, "at": time.monotonic() if _initial else float("-inf")}   # from scripts\start-control.ps1; empty: re-read at once


def _log(login, method, path, code, outcome):
    line = f"{time.strftime('%Y-%m-%d %H:%M:%S')} {login or '-'} {method} {path} {code} {outcome}\n"
    with _log_lock, open(LOG, "a", encoding="utf-8") as f:
        f.write(line)


def _allowed_logins():
    """The router's allowlist: <root>\\allowed-logins.txt if it exists, else the login this PC is signed in to Tailscale
    with (Get-AllowedLogins in scripts\\lib\\stack.ps1, the single place for this rule). Re-read every ALLOWED_TTL
    seconds, and every ALLOWED_RETRY seconds while empty: at logon the service starts before Tailscale is signed in
    (TASK-026), and a changed allowed-logins.txt applies without a restart."""
    with _allowed_lock:
        age = time.monotonic() - _allowed["at"]
        if age < (ALLOWED_TTL if _allowed["logins"] else ALLOWED_RETRY):
            return _allowed["logins"]
        stack = os.path.join(SCRIPTS, "lib", "stack.ps1")
        try:
            out = subprocess.run(["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command",
                                  f". '{stack}'; (Get-AllowedLogins '{ROOT}') -join ','"],
                                 capture_output=True, text=True, errors="replace", timeout=30).stdout
            logins = frozenset(x.strip().lower() for x in out.strip().split(",") if x.strip())
        except Exception:
            logins = frozenset()
        if logins != _allowed["logins"]:
            _log("-", "ALLOWLIST", "-", "-", f"{len(logins)} allowed login(s)")
        _allowed.update(logins=logins, at=time.monotonic())
        return logins


def _http_ok(url):
    try:
        with urllib.request.urlopen(url, timeout=2) as r:
            return r.status == 200
    except Exception:
        return False


def _listening(port):
    with socket.socket() as s:
        s.settimeout(0.5)
        return s.connect_ex(("127.0.0.1", port)) == 0


def _vram():
    try:
        out = subprocess.run(["nvidia-smi", "--query-gpu=memory.used,memory.total", "--format=csv,noheader,nounits"],
                             capture_output=True, text=True, timeout=10).stdout.splitlines()[0]
        used, total = (int(v) for v in out.split(","))
        return used, total
    except Exception:
        return None, None


def _status():
    router = _http_ok("http://127.0.0.1:4000/health/liveliness")
    swap = _http_ok("http://127.0.0.1:8080/health")
    used, total = _vram()
    return {
        "stack": "up" if router and swap else ("partial" if router or swap else "down"),
        "router": router,
        "llama_swap": swap,
        "model_loaded": next((name for port, name in MODEL_PORTS.items() if _listening(port)), None),
        "vram_used_mib": used,
        "vram_total_mib": total,
        "running": _running,
    }


def _run_script(name):
    """Runs scripts\\<name>.ps1 and returns (ok, lines). A throw comes back as its message only: the wrapper writes it
    to stderr as one line, where powershell -File would print the whole error record wrapped at the console width
    (which cut the game guard message, TASK-027)."""
    script = os.path.join(SCRIPTS, f"{name}.ps1")
    p = subprocess.run(["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command",
                        f"try {{ & '{script}'; exit 0 }} catch {{ [Console]::Error.WriteLine($_.Exception.Message); exit 1 }}"],
                       capture_output=True, text=True, errors="replace", timeout=300)
    out = [line.rstrip() for line in p.stdout.splitlines() if line.strip()]
    if p.returncode == 0:
        return True, out
    err = [line.strip() for line in p.stderr.splitlines() if line.strip()]
    return False, out + err[-1:]


class Handler(BaseHTTPRequestHandler):
    server_version = "local-ai-control"
    sys_version = ""

    def _send(self, code, body, login, outcome):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)
        _log(login, self.command, self.path, code, outcome)

    def _caller(self):
        """The allowlisted Tailscale login of a non-browser request, else None."""
        login = (self.headers.get("Tailscale-User-Login") or "").strip().lower()
        from_browser = "Origin" in self.headers or "Sec-Fetch-Site" in self.headers
        return login if login and not from_browser and login in _allowed_logins() else None

    def _handle(self):
        global _running
        routes = {"/health": "GET", "/status": "GET", "/up": "POST", "/down": "POST"}
        path = self.path.split("?", 1)[0]
        raw_login = (self.headers.get("Tailscale-User-Login") or "").strip().lower()
        if path not in routes:
            return self._send(404, {"error": "unknown route"}, raw_login, "unknown route")
        if self.command != routes[path]:
            return self._send(405, {"error": f"use {routes[path]}"}, raw_login, "wrong method")
        if path == "/health":
            return self._send(200, {"ok": True}, raw_login, "health")
        login = self._caller()
        if login is None:
            hint = "" if _allowed_logins() else " (the PC has no allowed logins yet: is Tailscale signed in there?)"
            return self._send(401, {"error": "not authorised: needs an allowlisted Tailscale login, not from a browser" + hint}, raw_login, "refused")
        if path == "/status":
            return self._send(200, _status(), login, "status")
        action = path.lstrip("/")
        if not _action_lock.acquire(blocking=False):
            return self._send(409, {"error": f"busy: {_running} is running"}, login, f"busy ({_running})")
        try:
            _running = action
            ok, lines = _run_script(f"ai-{action}")
        except subprocess.TimeoutExpired:
            ok, lines = False, [f"ai-{action} did not finish within 300 s"]
        finally:
            _running = None
            _action_lock.release()
        body = {"ok": ok, "action": action, "output": lines, "status": _status()}
        summary = (lines[0] if ok else lines[-1]) if lines else ""   # "Stack healthy ..." / "Stopped: ..." or the error
        return self._send(200 if ok else 422, body, login, f"{action} {'ok' if ok else 'failed'}: {summary}")

    do_GET = do_POST = _handle

    def log_message(self, *args):
        pass   # requests are logged by _log


if __name__ == "__main__":
    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    _log("-", "START", "-", "-", f"listening on {HOST}:{PORT}, {len(_allowed['logins'])} allowed login(s) at start")
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
