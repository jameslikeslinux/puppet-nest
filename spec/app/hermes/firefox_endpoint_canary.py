"""Isolated real-image HTTPS endpoint canary; never mounts an owner profile.

Run with --image <locally available immutable image ID>. Only setup/cleanup
uses Podman. All public browser calls use TLS-verified HTTPS with no kubeconfig
and with subprocess execution forbidden in the client. Not production acceptance.
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import http.client
import importlib.util
import json
import os
from pathlib import Path
import ssl
import subprocess
import sys
import tempfile
import threading
import time
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).parent))
from test_secure_browser_firefox_ui import load_tool

TEXT = "Nonsecret endpoint source text alpha beta gamma.\n" * 180


class Fixture(BaseHTTPRequestHandler):
    def do_GET(self):
        body = ('<!doctype html><title>Endpoint fixture ' + self.path.strip('/') + '</title>'
                + '<textarea id="paragraphs" aria-label="Paragraphs"></textarea>'
                + '<textarea id="coordinate" aria-label="Coordinate paragraphs"></textarea>'
                + '<div id="editor" contenteditable="true" aria-label="Public editor"></div>'
                + '<p>Generic chat message</p>' * 300 + '<pre>' + TEXT + '</pre>'
                + '<input id="note" aria-label="Note"><input type="password" id="protected">'
                + '<button id="apply" onclick="document.getElementById(\'result\').textContent=\'Applied\'">Apply</button>'
                + '<p id="result">Ready</p>').encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


class TLSProxy(BaseHTTPRequestHandler):
    backend_port = 0

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        connection = http.client.HTTPConnection("127.0.0.1", self.backend_port, timeout=90)
        try:
            connection.request("POST", self.path, self.rfile.read(length),
                               {"Content-Type": "application/json", "Authorization": self.headers.get("Authorization", "")})
            response = connection.getresponse()
            raw = response.read()
            self.send_response(response.status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)
        except (OSError, http.client.HTTPException):
            self.send_error(503, "isolated endpoint unavailable")
        finally:
            connection.close()

    def log_message(self, *args):
        pass


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--image", required=True)
    parser.add_argument("--iterations", type=int, default=12)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    if not args.image.startswith("sha256:"):
        raise SystemExit("Use a verified immutable local image ID")
    container = "nest-firefox-endpoint-fixture-t06982fa3"
    latencies = []
    started = time.monotonic()
    infrastructure_run = subprocess.run
    with tempfile.TemporaryDirectory(prefix="firefox-endpoint-") as directory:
        work = Path(directory)
        token = work / "token"
        token.write_text("isolated-nonsecret-fixture-credential-only")
        token.chmod(0o444)
        key, cert = work / "tls.key", work / "tls.crt"
        subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1", "-keyout", str(key), "-out", str(cert), "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost"], check=True, capture_output=True)
        fixture = ThreadingHTTPServer(("0.0.0.0", 0), Fixture)
        threading.Thread(target=fixture.serve_forever, daemon=True).start()
        subprocess.run(["sudo", "-n", "podman", "run", "--detach", "--name", container, "--cap-add", "SETFCAP", "--shm-size", "1g", "--publish", "127.0.0.1::8766", "--volume", f"{token}:/run/nest-firefox-bridge/token:ro", "--env", "FIREFOX_BRIDGE_TOKEN_FILE=/run/nest-firefox-bridge/token", "--env", "FIREFOX_CONTROL_PROTOCOL=firefox-bidi-ui-v2", args.image], check=True, capture_output=True)
        try:
            ports = json.loads(subprocess.run(["sudo", "-n", "podman", "inspect", container], check=True, capture_output=True, text=True).stdout)[0]["NetworkSettings"]["Ports"]["8766/tcp"]
            TLSProxy.backend_port = int(ports[0]["HostPort"])
            endpoint = ThreadingHTTPServer(("127.0.0.1", 0), TLSProxy)
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.load_cert_chain(cert, key)
            endpoint.socket = context.wrap_socket(endpoint.socket, server_side=True)
            threading.Thread(target=endpoint.serve_forever, daemon=True).start()
            tool, _ = load_tool()
            tool.CONTROL_MODE = "firefox-bidi-ui-v2"
            tool.PUBLIC_URL = f"https://localhost:{endpoint.server_port}"
            tool.BRIDGE_TOKEN_FILE = token
            tool.CONTROLLER_STATE_DIR = work / "controller"
            def call(name, payload):
                begin = time.monotonic()
                value = json.loads(getattr(tool, name)(payload))
                latencies.append(time.monotonic() - begin)
                if value.get("status") in {"error", "unsupported", "blocked"}:
                    raise RuntimeError(f"{name}: {value.get('message') or value.get('error')}")
                return value
            with patch.dict(os.environ, {"KUBECONFIG": "/nonexistent", "SSL_CERT_FILE": str(cert)}), patch.object(tool.subprocess, "run", side_effect=AssertionError("client subprocess/cluster access forbidden")):
                deadline = time.monotonic() + 45
                while True:
                    result = json.loads(tool.secure_browser_page_snapshot_tool({}))
                    if result.get("status") == "ok" and result.get("tab_count"):
                        break
                    if time.monotonic() > deadline:
                        raise RuntimeError("isolated image endpoint did not become ready")
                    time.sleep(.5)
                generation = result["browser_generation"]
                for index in range(3):
                    workflow = "endpoint-survivor-" + str(index)
                    call("secure_browser_tab_lifecycle_tool", {"action": "acquire", "workflow_id": workflow})
                    call("secure_browser_navigate_tool", {"url": f"http://host.containers.internal:{fixture.server_port}/survivor-{index}", "workflow_id": workflow})
                    call("secure_browser_tab_lifecycle_tool", {"action": "keep_open", "workflow_id": workflow})
                before = call("secure_browser_page_snapshot_tool", {})
                identities = {tab["locator"] for tab in before["tabs"]}
                for index in range(args.iterations):
                    workflow = "endpoint-cycle-" + str(index)
                    call("secure_browser_tab_lifecycle_tool", {"action": "acquire", "workflow_id": workflow})
                    call("secure_browser_navigate_tool", {"url": f"http://host.containers.internal:{fixture.server_port}/cycle-{index}", "workflow_id": workflow})
                    action = {"selector": "#note", "text": "safe fixture input", "workflow_id": workflow, "action_key": f"type-{index}"}
                    call("secure_browser_type_tool", action)
                    typed = call("secure_browser_query_tool", {"expression": 'document.querySelector("#note").value'})
                    assert typed["value"] == "safe fixture input"
                    protected = call("secure_browser_query_tool", {"expression": 'document.querySelector("#protected").value'})
                    assert protected["value"] == "<redacted>"
                    call("secure_browser_click_tool", {"selector": "#apply", "workflow_id": workflow, "action_key": f"click-{index}"})
                    clicked = call("secure_browser_query_tool", {"expression": 'document.querySelector("#result").textContent'})
                    assert clicked["value"] == "Applied"
                    replay = call("secure_browser_type_tool", action)
                    assert replay.get("status") in {"replayed", "duplicate", "already_delivered"} or replay.get("deduplicated"), replay
                    cursor, text = None, ""
                    while True:
                        read = call("secure_browser_query_tool", {"expression": 'document.readText("pre",0)', "cursor": cursor})
                        text += read["value"]["text"]
                        cursor = read.get("nextCursor")
                        if cursor is None:
                            break
                    assert text == TEXT
                    if index == 0:
                        paragraphs = "First paragraph.\n\nSecond paragraph.\n"
                        for selector in ("#paragraphs", "#editor"):
                            suffix = selector.removeprefix("#")
                            call("secure_browser_type_tool", {"selector": selector, "text": "Existing text",
                                 "workflow_id": workflow, "action_key": "seed-" + suffix})
                            replacement = {"selector": selector, "text": paragraphs, "mode": "replace",
                                           "workflow_id": workflow, "action_key": "replace-" + suffix}
                            call("secure_browser_type_tool", replacement)
                            expression = f'document.querySelector("{selector}").' + ("value" if selector == "#paragraphs" else "innerText")
                            assert call("secure_browser_query_tool", {"expression": expression})["value"] == paragraphs
                            assert call("secure_browser_type_tool", replacement)["status"] == "already_delivered"
                        call("secure_browser_click_tool", {"selector": "#coordinate", "workflow_id": workflow, "action_key": "focus-coordinate"})
                        snap = call("secure_browser_page_snapshot_tool", {})
                        node = next(n for n in snap["nodes"] if n.get("role") == "entry" and "focused" in n.get("states", []) and n.get("rect"))
                        rect = node["rect"]
                        call("secure_browser_type_tool", {"coordinate": [rect["x"] + rect["width"] // 2, rect["y"] + rect["height"] // 2],
                             "text": paragraphs, "workflow_id": workflow, "action_key": "coordinate-paragraphs"})
                        assert call("secure_browser_query_tool", {"expression": 'document.querySelector("#coordinate").value'})["value"] == paragraphs
                    call("secure_browser_tab_lifecycle_tool", {"action": "release", "workflow_id": workflow})
                    snapshot = call("secure_browser_page_snapshot_tool", {})
                    assert snapshot["browser_generation"] == generation
                    assert identities <= {tab["locator"] for tab in snapshot["tabs"]}
                    print(json.dumps({"cycle": index + 1, "elapsed": round(time.monotonic() - started, 3)}), flush=True)
                status = call("secure_browser_status_tool", {})
                assert status["control_mode_matches_browser"]
                # Explicit infrastructure maintenance on this disposable image
                # only. This is not a browser tool or a recovery of owner state.
                refresh = (
                    "import os,pathlib,signal,subprocess; "
                    "script='/opt/nest/firefox/bin/firefox-bridge-server.py'; "
                    "pids=[int(p.name) for p in pathlib.Path('/proc').iterdir() if p.name.isdigit() "
                    "and (p/'cmdline').exists() and (p/'cmdline').read_bytes().split(bytes([0]))[1:]==[script.encode(),b'']]; "
                    "assert len(pids)==1,pids; os.kill(pids[0],signal.SIGTERM); "
                    "subprocess.Popen(['python3',script],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)"
                )
                refreshed = infrastructure_run(["sudo", "-n", "podman", "exec", container, "python3", "-c", refresh], capture_output=True, text=True)
                if refreshed.returncode:
                    raise RuntimeError("isolated bridge refresh setup failed: " + refreshed.stderr[-1000:])
                # Bounded readiness observation only; never resend a mutation.
                for attempt in range(20):
                    observed = json.loads(tool.secure_browser_page_snapshot_tool({}))
                    if observed.get("status") == "ok":
                        break
                    time.sleep(.1)
                assert observed.get("browser_generation") == generation
                assert identities <= {tab["locator"] for tab in observed["tabs"]}
                real_port = TLSProxy.backend_port
                TLSProxy.backend_port = 0
                outage = json.loads(tool.secure_browser_status_tool({}))
                assert outage["status"] == "error"
                TLSProxy.backend_port = real_port
                observed = call("secure_browser_page_snapshot_tool", {})
                assert observed["browser_generation"] == generation
                assert identities <= {tab["locator"] for tab in observed["tabs"]}
            endpoint.shutdown()
            endpoint.server_close()
            result = {"passed": True, "bridge_refresh_preserved_browser": True, "endpoint_outage_preserved_browser": True, "iterations": args.iterations, "duration_seconds": round(time.monotonic() - started, 3), "operations": len(latencies), "mean_seconds": round(sum(latencies) / len(latencies), 3), "max_seconds": round(max(latencies), 3), "surviving_tab_count": len(identities), "generation_unchanged": True, "client_subprocess_forbidden": True, "kubeconfig": "nonexistent", "tls_verification": "default context with isolated fixture CA; localhost endpoint only", "fixture_text_sha256": hashlib.sha256(TEXT.encode()).hexdigest(), "image": args.image, "scope": "isolated actual-image public adapter; not production browser.eyrie acceptance"}
            Path(args.output).write_text(json.dumps(result, indent=2) + "\n")
            print(json.dumps(result), flush=True)
        finally:
            fixture.shutdown()
            fixture.server_close()
            # Clean UI termination only. Never force-kill even this test browser.
            subprocess.run(["sudo", "-n", "podman", "exec", container, "env", "DISPLAY=:1", "xdotool", "key", "--clearmodifiers", "ctrl+q"], check=False, capture_output=True)
            try:
                subprocess.run(["sudo", "-n", "podman", "wait", container], timeout=30, check=True, capture_output=True)
                subprocess.run(["sudo", "-n", "podman", "rm", container], check=True, capture_output=True)
            except subprocess.TimeoutExpired:
                print("Isolated browser did not exit gracefully; retained for diagnosis, no forced stop", flush=True)


if __name__ == "__main__":
    main()
