"""Private in-workload BiDi reads; no Kubernetes or externally exposed debugger."""
from __future__ import annotations

import contextlib
import json
import time
from typing import Any

import websockets.sync.client


class CdpSession:
    protocol = "bidi"

    def __init__(self):
        self.next_id = 0
        self.ws = websockets.sync.client.connect(
            "ws://127.0.0.1:9222/session", open_timeout=5, close_timeout=2,
            max_size=2_000_000, compression=None, proxy=None,
        )
        try:
            self._bidi("session.new", {"capabilities": {"alwaysMatch": {}}})
        except Exception:
            self.ws.close()
            raise

    def _bidi(self, method: str, params: dict | None = None) -> dict:
        self.next_id += 1
        self.ws.send(json.dumps({"id": self.next_id, "method": method, "params": params or {}}))
        deadline = time.monotonic() + 10
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise RuntimeError("private Firefox observation timed out")
            reply = json.loads(self.ws.recv(timeout=remaining))
            if reply.get("id") == self.next_id:
                if reply.get("type") == "error" or "error" in reply:
                    raise RuntimeError("private Firefox observation failed")
                return reply.get("result") or {}

    def _bidi_contexts(self) -> list[dict]:
        return [item for item in self._bidi("browsingContext.getTree").get("contexts", []) if isinstance(item, dict)]

    @staticmethod
    def _bidi_value(value: dict) -> Any:
        raw = value.get("value")
        if value.get("type") == "array" and isinstance(raw, list):
            return [CdpSession._bidi_value(item) for item in raw]
        if value.get("type") == "object" and isinstance(raw, list):
            return {str(key.get("value") if isinstance(key, dict) else key): CdpSession._bidi_value(item) for key, item in raw}
        return raw

    def close(self):
        # End the controller session, never the Firefox process or its tabs.
        with contextlib.suppress(Exception):
            self._bidi("session.end")
        self.ws.close()


def _with_browser(callback):
    browser = CdpSession()
    try:
        return callback(browser)
    finally:
        browser.close()
