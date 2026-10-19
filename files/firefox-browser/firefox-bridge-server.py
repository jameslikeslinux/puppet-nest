#!/usr/bin/env python3
"""Authenticated fixed-function HTTP bridge for the owner-visible Firefox.

Contour terminates supervised TLS. Only this guarded API is routed, never the
private WebDriver/BiDi listeners. Disconnects never cancel/replay UI actions.
"""
from __future__ import annotations

import argparse
import fcntl
import hashlib
import hmac
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import time

MAX_REQUEST = 32_768
MAX_RESPONSE = 8_000_000
API_PATH = "/_nest/bridge/v1"
ROOT = Path(__file__).resolve().parent
TOKEN_PATH = Path(os.environ.get("FIREFOX_BRIDGE_TOKEN_FILE", "/run/nest-firefox-bridge/token"))
LOCK_PATH = Path(os.environ.get("FIREFOX_BRIDGE_LOCK", "/tmp/nest-firefox/endpoint.lock"))
FIELDS = {
    "status": set(), "diagnostics": set(), "snapshot": set(), "screenshot": set(),
    "query": {"expression", "cursor"}, "wait": {"max_wait_seconds"},
    "checkout_readback": {"safe_item_nickname", "max_wait_seconds"},
    "tabs": {"action", "workflow_id", "lease_seconds"},
    "navigate": {"url", "workflow_id", "lease_seconds", "max_wait_seconds"},
    "scroll": {"workflow_id", "direction", "amount"},
    "click": {"workflow_id", "locator", "coordinate", "action_key", "max_wait_seconds"},
    "type": {"workflow_id", "locator", "coordinate", "action_key", "text"},
    "selector_action": {"workflow_id", "operation", "selector", "expected_url", "expected_generation", "expected_tab", "action_key", "text", "max_wait_seconds"},
}


def validate(envelope):
    if not isinstance(envelope, dict) or set(envelope) != {"command", "payload"}:
        raise ValueError("expected a fixed command and payload only")
    command, payload = envelope["command"], envelope["payload"]
    if not isinstance(command, str) or command not in FIELDS or not isinstance(payload, dict) or set(payload) - FIELDS[command]:
        raise ValueError("unsupported command or payload fields")
    if any(isinstance(value, str) and len(value) > 4096 for value in payload.values()):
        raise ValueError("payload string exceeds the input budget")
    return command, payload


def worker():
    command, payload = validate(json.load(sys.stdin))
    spec = importlib.util.spec_from_file_location("firefox_ui_bridge", ROOT / "firefox-ui-bridge.py")
    ui = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(ui)
    if command == "query":
        import secure_browser_bidi as bidi
        result = bidi.query(ui.command_snapshot({}), str(payload.get("expression") or ""),
                            cursor=payload.get("cursor"), snapshot_reader=lambda: ui.command_snapshot({}))
    else:
        result = ui.COMMANDS[command](payload)
        if command == "status" and os.environ.get("FIREFOX_CONTROL_PROTOCOL") == "firefox-bidi-ui-v2":
            import secure_browser_bidi as bidi
            result["bidi_available"] = bidi.probe()
    result["bridge_diagnostics"] = {
        "command": command,
        "source_sha256": hashlib.sha256((ROOT / "firefox-ui-bridge.py").read_bytes()).hexdigest(),
        "endpoint_source_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "transport": "authenticated service endpoint",
    }
    return result


class Handler(BaseHTTPRequestHandler):
    server_version = "NestFirefoxBridge/1"

    def setup(self):
        super().setup()
        self.connection.settimeout(5)

    def log_message(self, *args):
        pass  # Never log URLs, payloads, headers or browser responses.

    def reply(self, code, value):
        raw = json.dumps(value, separators=(",", ":")).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Connection", "close")
        self.end_headers()
        try:
            self.wfile.write(raw)
        except (BrokenPipeError, ConnectionResetError):
            pass  # Delivery may have completed: never retry it.

    def do_POST(self):
        started = time.monotonic()
        if self.path != API_PATH:
            return self.reply(404, {"status": "error", "message": "unknown bridge route"})
        if self.headers.get("Origin") or self.headers.get("Upgrade") or self.headers.get("Transfer-Encoding"):
            return self.reply(403, {"status": "error", "message": "browser-origin and upgraded requests are forbidden"})
        expected = "Bearer " + self.server.bridge_token
        if not hmac.compare_digest(self.headers.get("Authorization", ""), expected):
            return self.reply(401, {"status": "error", "message": "endpoint authentication required"})
        try:
            if self.headers.get_content_type() != "application/json":
                raise ValueError("expected JSON")
            if len(self.headers.get_all("Content-Length", [])) != 1:
                raise ValueError("expected one content length")
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size <= MAX_REQUEST:
                raise ValueError("request size exceeds the input budget")
            envelope = json.loads(self.rfile.read(size))
            command, payload = validate(envelope)
        except (ValueError, OSError):
            return self.reply(400, {"status": "error", "message": "invalid bounded command envelope"})
        LOCK_PATH.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        with LOCK_PATH.open("a+") as lock:
            os.fchmod(lock.fileno(), 0o600)
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                return self.reply(409, {"status": "error", "message": "shared Firefox endpoint busy; no operation started"})
            # Child retains this lock even if the HTTP server is refreshed.
            # Only the bridge worker is bounded; Firefox is never terminated.
            budget = min(len(str(payload.get("text") or payload.get("url") or "")), 4096) // 5
            try:
                proc = subprocess.run(
                    [sys.executable, str(Path(__file__).resolve()), "--worker"],
                    input=json.dumps(envelope), text=True, capture_output=True,
                    timeout=50 + budget, pass_fds=(lock.fileno(),), check=False,
                )
                if len(proc.stdout.encode()) > MAX_RESPONSE or proc.returncode:
                    raise RuntimeError("bridge worker failed")
                result = json.loads(proc.stdout)
                if not isinstance(result, dict):
                    raise ValueError("invalid worker response")
            except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired):
                result = {"status": "error", "message": "bounded Firefox operation failed or timed out; delivery may be uncertain; retain the action key"}
        result["elapsed_ms"] = int((time.monotonic() - started) * 1000)
        self.reply(200, result)


class Server(ThreadingHTTPServer):
    daemon_threads = True
    request_queue_size = 8


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--worker", action="store_true")
    args = parser.parse_args()
    if args.worker:
        try:
            result = worker()
        except Exception as exc:
            # Existing command validation emits privacy-safe errors. Driver
            # exceptions are already scrubbed at their source.
            result = {"status": "error", "message": str(exc)[:1000]}
        print(json.dumps(result))
        return
    token = TOKEN_PATH.read_text(encoding="utf-8").strip()
    if len(token) < 32 or any(char.isspace() for char in token):
        raise SystemExit("Missing or invalid endpoint credential")
    server = Server(("0.0.0.0", 8766), Handler)
    server.bridge_token = token
    server.serve_forever()


if __name__ == "__main__":
    main()
