"""Endpoint regressions: routine browser control must never use Kubernetes."""
import importlib.util
import io
import json
from email.message import Message
from pathlib import Path
import tempfile
import threading
import urllib.error
import urllib.request
from unittest.mock import patch

from test_secure_browser_firefox_ui import load_tool, parsed, REPO_ROOT


class Reply(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()


def test_endpoint_without_kubeconfig_and_no_subprocess():
    module, _ = load_tool()
    seen = []
    def request(req, **kwargs):
        seen.append((req, kwargs))
        return Reply(json.dumps({"status": "ok", "operation": "snapshot"}).encode())
    with tempfile.TemporaryDirectory() as tmpdir:
        module.BRIDGE_TOKEN_FILE = Path(tmpdir) / "auth"
        module.BRIDGE_TOKEN_FILE.write_text("fixture-not-a-real-credential")
        with patch.dict(module.os.environ, {"KUBECONFIG": "/nonexistent"}), patch("urllib.request.OpenerDirector.open", side_effect=request), patch.object(module.subprocess, "run", side_effect=AssertionError("routine subprocess forbidden")):
            assert module._bridge("snapshot", {})["status"] == "ok"
    req, options = seen[0]
    assert req.full_url == "https://browser.eyrie/_nest/bridge/v1"
    assert json.loads(req.data) == {"command": "snapshot", "payload": {}}
    assert req.get_header("Authorization") == "Bearer fixture-not-a-real-credential"
    assert options["timeout"] <= 70


def test_endpoint_query_never_loads_cluster_connector():
    module, _ = load_tool()
    module.CONTROL_MODE = "firefox-bidi-ui-v2"
    seen = []
    module._bridge = lambda command, payload, **kw: seen.append((command, payload)) or {"status": "ok"}
    assert parsed(module.secure_browser_query_tool({"expression": "document.title"}))["status"] == "ok"
    assert seen == [("query", {"expression": "document.title", "cursor": None})]


def test_endpoint_outage_has_no_fallback_and_no_retry():
    module, _ = load_tool()
    with tempfile.TemporaryDirectory() as tmpdir:
        module.BRIDGE_TOKEN_FILE = Path(tmpdir) / "auth"
        module.BRIDGE_TOKEN_FILE.write_text("fixture-not-a-real-credential")
        with patch("urllib.request.OpenerDirector.open", side_effect=OSError("offline")) as opened, patch.object(module.subprocess, "run", side_effect=AssertionError("cluster fallback forbidden")):
            result = parsed(module.secure_browser_status_tool({}))
    assert result["status"] == "error"
    assert "endpoint" in result["message"]
    assert opened.call_count == 1


def test_http_refusal_reports_only_status_without_retry_or_body():
    module, _ = load_tool()
    with tempfile.TemporaryDirectory() as tmpdir:
        module.BRIDGE_TOKEN_FILE = Path(tmpdir) / "auth"
        module.BRIDGE_TOKEN_FILE.write_text("fixture-not-a-real-credential")
        failure = urllib.error.HTTPError("https://browser.eyrie/PRIVATE", 409, "PRIVATE", Message(), io.BytesIO(b"PRIVATE"))
        with patch("urllib.request.OpenerDirector.open", side_effect=failure) as opened, patch.object(module.subprocess, "run", side_effect=AssertionError("subprocess forbidden")):
            result = parsed(module.secure_browser_status_tool({}))
        assert "HTTP 409" in result["message"] and "PRIVATE" not in result["message"]
        assert opened.call_count == 1


def test_endpoint_refuses_non_https_and_redirects():
    module, _ = load_tool()
    module.PUBLIC_URL = "http://browser.eyrie/"
    with patch("urllib.request.OpenerDirector.open", side_effect=AssertionError("network forbidden in rejection test")), patch.object(module.subprocess, "run", side_effect=AssertionError("subprocess forbidden in rejection test")):
        result = parsed(module.secure_browser_status_tool({}))
    assert result["status"] == "error"
    assert "HTTPS" in result["message"]
    try:
        module._NoRedirect().redirect_request(None, None, 302, "redirect", {}, "https://wrong.example/")
    except RuntimeError:
        pass
    else:
        raise AssertionError("redirect accepted")


def test_server_http_auth_envelope_and_busy_lock():
    source = REPO_ROOT / "files/firefox-browser/firefox-bridge-server.py"
    spec = importlib.util.spec_from_file_location("endpoint", source)
    server_module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(server_module)
    with tempfile.TemporaryDirectory() as tmpdir:
        server_module.LOCK_PATH = Path(tmpdir) / "endpoint.lock"
        server = server_module.Server(("127.0.0.1", 0), server_module.Handler)
        server.bridge_token = "nonsecret-test-credential-not-real"
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        def post(body, token="nonsecret-test-credential-not-real", extra=None):
            req = urllib.request.Request(f"http://127.0.0.1:{server.server_port}/_nest/bridge/v1", data=json.dumps(body).encode(),
                                         headers={"Content-Type": "application/json", "Authorization": "Bearer " + token, **(extra or {})})
            try:
                with urllib.request.urlopen(req, timeout=2) as reply:
                    return reply.status, json.load(reply)
            except urllib.error.HTTPError as exc:
                return exc.code, json.load(exc)
        try:
            envelope = {"command": "snapshot", "payload": {}}
            with patch.object(server_module.subprocess, "run", side_effect=AssertionError("unauthorized dispatch")):
                assert post(envelope, token="wrong")[0] == 401
                assert post(envelope, extra={"Origin": "https://malicious.example"})[0] == 403
                assert post({**envelope, "source": "print('forbidden')"})[0] == 400
                assert post({"command": "exec", "payload": {}})[0] == 400
                assert post({"command": "snapshot", "payload": {"script": "forbidden"}})[0] == 400
                with server_module.LOCK_PATH.open("a+") as lock:
                    server_module.fcntl.flock(lock, server_module.fcntl.LOCK_EX)
                    assert post(envelope)[0] == 409
            import subprocess
            with patch.object(server_module.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, '{"status":"ok"}', '')) as run:
                status, reply = post(envelope)
                assert status == 200 and reply["status"] == "ok"
                assert run.call_args.kwargs["pass_fds"]
                assert run.call_args.args[0][-1] == "--worker"
                assert json.loads(run.call_args.kwargs["input"]) == envelope
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)


def test_oauth_uses_same_endpoint_and_never_executes_scripts():
    module, _ = load_tool()
    seen = []
    def bridge(command, payload):
        seen.append((command, payload))
        return {"status": "ok", "title": "Fixture", "url": "https://fixture.example/", "readback": {"title": "Fixture", "url": "https://fixture.example/"}}
    module._bridge = bridge
    spec = importlib.util.spec_from_file_location("oauth_fixture", REPO_ROOT / "files/app/hermes/secure_browser_oauth_tool.py")
    oauth = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(oauth)
    oauth._adapter = lambda: module
    assert json.loads(oauth.secure_browser_oauth_status_tool({"include_page": False}))["available"]
    oauth._navigate("https://fixture.example/")
    assert [command for command, payload in seen] == ["status", "tabs", "navigate"]
    seen.clear()
    result = json.loads(oauth.secure_browser_oauth_read_only_query_tool({"expression": "document.cookie"}))
    assert result["status"] == "error" and not seen
    assert json.loads(oauth.secure_browser_oauth_read_only_query_tool({"expression": "document.title"}))["value"] == "Fixture"
    assert [command for command, payload in seen] == ["snapshot"]


if __name__ == "__main__":
    for name in sorted(name for name in globals() if name.startswith("test_")):
        globals()[name]()
    print("Firefox endpoint regressions passed")
