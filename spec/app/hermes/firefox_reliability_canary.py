"""Opt-in lifecycle canary for an empty, isolated Firefox pod; never owner PVCs.

The caller supplies source via stdin. Run in a fixture pod whose main process
is sleep, so this test can start and stop its own launcher without pod restarts.
"""
from __future__ import annotations

import ast
import contextlib
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import threading
import time
import types
from urllib.parse import urlparse


def main() -> None:
    if os.environ.get("NEST_ISOLATED_BROWSER_CANARY") != "t_06982fa3":
        raise SystemExit("Refusing: isolated fixture acknowledgement missing")
    envelope = json.load(sys.stdin)
    home = Path("/home/kasm-user") / ("reliability-" + str(time.time_ns()))
    profile = home / ".mozilla/firefox/nest-secure-browser"
    profile.mkdir(parents=True)
    # Known test preferences only; never read cookies, storage or session files.
    (profile / "user.js").write_text(
        'user_pref("browser.startup.page", 3);\n'
        'user_pref("browser.sessionstore.resume_from_crash", true);\n'
        'user_pref("browser.warnOnQuitShortcut", false);\n'
        'user_pref("browser.tabs.warnOnClose", false);\n'
    )
    os.environ["FIREFOX_UI_STATE_DIR"] = str(home / ".local/state/nest-firefox-ui")
    os.environ["DISPLAY"] = ":1"
    bridge = types.ModuleType("fixture_bridge")
    exec(compile(envelope["bridge"], "bridge", "exec"), bridge.__dict__)
    bootstrap = (
        "import io,json,sys; e=json.load(sys.stdin); sys.argv=['bridge',e['command']]; "
        "sys.stdin=io.StringIO(json.dumps(e['payload'])); "
        "exec(compile(e['source'],'bridge','exec'),{'__name__':'__main__'})"
    )
    latencies: list[float] = []

    def invoke(command: str, payload: dict | None = None) -> dict:
        started = time.monotonic()
        result = subprocess.run(
            ["python3", "-c", bootstrap],
            input=json.dumps({"source": envelope["bridge"], "command": command, "payload": payload or {}}),
            capture_output=True, text=True, timeout=60,
        )
        latencies.append(time.monotonic() - started)
        if result.returncode:
            raise RuntimeError(result.stdout[-1000:] + result.stderr[-500:])
        return json.loads(result.stdout)

    def snapshot() -> dict:
        return invoke("snapshot")

    fixture_text = ("Nonsecret source text: alpha beta gamma.\n" * 180)
    fixture_authentication = {"seen": False}

    class Fixture(BaseHTTPRequestHandler):
        def do_GET(self):
            body = (
                "<!doctype html><title>Fixture " + self.path.strip("/") + "</title>"
                + ('<p>Nonsecret long chat message</p>' * int(envelope.get("message_nodes", 0))) +
                '<pre>' + fixture_text + '</pre><input id="note" aria-label="Note">'
                '<input type="password" id="protected"><button id="apply" '
                'onclick="document.getElementById(\'result\').textContent=\'Applied\'">Apply</button>'
                '<p id="result">Ready</p>'
            ).encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.send_header("Set-Cookie", "fixture_session=nonsecret; SameSite=Lax")
            self.end_headers()
            self.wfile.write(body)
            if self.path == "/authentication-check":
                fixture_authentication["seen"] = "fixture_session=nonsecret" in self.headers.get("Cookie", "")

        def log_message(self, format, *args):
            pass

    server = ThreadingHTTPServer(("127.0.0.1", 0), Fixture)

    threading.Thread(target=server.serve_forever, daemon=True).start()
    base = f"http://127.0.0.1:{server.server_port}"

    # Exercise the actual shipped BiDi session and bounded query code. Only
    # dependency loading is reduced for the image, which lacks Hermes itself.
    import websockets.sync.client
    tree = ast.parse(envelope["legacy"])
    session_class = next(node for node in tree.body if isinstance(node, ast.ClassDef) and node.name == "CdpSession")
    names = {"__init__", "close", "_bidi", "_bidi_value", "_bidi_contexts"}
    session_class.body = [node for node in session_class.body if isinstance(node, ast.FunctionDef) and node.name in names]
    legacy = types.ModuleType("fixture.secure_browser_local_bidi")
    legacy.__dict__.update({"Any": object, "contextlib": contextlib, "socket": socket, "urlparse": urlparse,
                            "websockets": websockets, "json": json, "REMOTE_DEBUG_PORT": 9222,
                            "CDP_MAX_MESSAGE_BYTES": 8_000_000})
    exec(compile(ast.Module(body=[session_class], type_ignores=[]), "legacy", "exec"), legacy.__dict__)

    def with_browser(callback):
        browser = legacy.CdpSession("bidi+ws://127.0.0.1:9222/session")
        try:
            return callback(browser)
        finally:
            browser.close()

    setattr(legacy, "_with_browser", with_browser)
    package = types.ModuleType("fixture")
    package.__path__ = []
    sys.modules["fixture"] = package
    sys.modules[legacy.__name__] = legacy
    bidi = types.ModuleType("fixture.secure_browser_bidi")
    bidi.__package__ = "fixture"
    exec(compile(envelope["bidi"], "bidi", "exec"), bidi.__dict__)

    def query(expression: str, cursor=None):
        observed = snapshot()
        return bidi.query(observed, expression, cursor=cursor, snapshot_reader=snapshot)

    def launch():
        process = subprocess.Popen(
            ["sh", "-c", envelope["launcher"]],
            env={**os.environ, "FIREFOX_HOME": str(home), "LAUNCH_URL": "", "FIREFOX_CONTROL_PROTOCOL": "firefox-bidi-ui-v2"},
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        time.sleep(4)
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            try:
                if snapshot()["tab_count"]:
                    return process
            except Exception:
                pass
            time.sleep(.5)
        raise RuntimeError("isolated Firefox startup failed")

    def stop(process, graceful=True):
        if graceful:
            bridge._xdotool("key", "--clearmodifiers", "ctrl+q")
        else:
            os.kill(bridge._browser_pid(), signal.SIGTERM)
        process.wait(timeout=30)
        time.sleep(1)

    started = time.monotonic()
    process = launch()
    try:
        for index in range(3):
            workflow = "fixture-" + str(index)
            invoke("tabs", {"action": "acquire", "workflow_id": workflow})
            invoke("navigate", {"workflow_id": workflow, "url": base + "/" + str(index), "max_wait_seconds": 1})
        before = snapshot()
        generation = before["browser_generation"]
        protected_ids = {tab["tab_identity"] for tab in before["tabs"]}
        cursor = None
        text = ""
        while True:
            result = query('document.readText("pre",0)', cursor)
            text += result["value"]["text"]
            cursor = result["nextCursor"]
            if result["complete"]:
                break
        assert text == fixture_text
        for index in range(int(envelope.get("iterations", 12))):
            invoke("tabs", {"action": "acquire", "workflow_id": "transient"})
            invoke("navigate", {"workflow_id": "transient", "url": base + "/temporary", "max_wait_seconds": 1})
            action = {"workflow_id": "transient", "operation": "type", "selector": "#note", "text": "once", "action_key": "typed-" + str(index)}
            assert invoke("selector_action", action)["status"] == "delivered"
            assert invoke("selector_action", action)["status"] == "already_delivered"
            assert query('document.querySelector("#note").value')["value"] == "once"
            assert query('document.querySelector("#protected").value')["value"] == "<redacted>"
            assert invoke("tabs", {"action": "release", "workflow_id": "transient"})["status"] == "released_closed_owned_tab"
            observed = snapshot()
            assert observed["browser_generation"] == generation
            assert {tab["tab_identity"] for tab in observed["tabs"]} == protected_ids
            print(json.dumps({"iteration": index + 1, "elapsed_seconds": round(time.monotonic() - started, 3),
                              "retained_tabs": len(protected_ids)}), flush=True)
        retained = [tab["name"] for tab in snapshot()["tabs"]]
        stop(process)
        process = launch()
        time.sleep(2)
        after = snapshot()
        assert [tab["name"] for tab in after["tabs"]] == retained
        assert after["browser_generation"] != generation
        assert invoke("tabs", {"action": "status"})["reconciliation"]["preserved_uncertain"]
        invoke("tabs", {"action": "acquire", "workflow_id": "authentication-check"})
        invoke("navigate", {"workflow_id": "authentication-check", "url": base + "/authentication-check", "max_wait_seconds": 1})
        assert fixture_authentication["seen"]
        invoke("tabs", {"action": "release", "workflow_id": "authentication-check"})
        evidence = {"status": "passed", "iterations": envelope.get("iterations", 12),
                          "duration_seconds": round(time.monotonic() - started, 3),
                          "operations": len(latencies), "max_operation_seconds": round(max(latencies), 3),
                          "mean_operation_seconds": round(sum(latencies) / len(latencies), 3),
                          "text_sha256": hashlib.sha256(text.encode()).hexdigest(),
                          "retained_tabs": len(retained), "owner_identities_unchanged_during_soak": True,
                          "restored_after_graceful_exit": True, "fixture_authentication_retained": True}
        Path("/tmp/firefox-reliability-result.json").write_text(json.dumps(evidence))
        print(json.dumps(evidence), flush=True)
    finally:
        if process.poll() is None:
            stop(process)
        server.shutdown()


if __name__ == "__main__":
    main()
