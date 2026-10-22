"""Creation delivery boundaries and finite public recovery; synthetic scopes only."""
import json
from types import SimpleNamespace

import pytest

from test_firefox_windows import A, B, close, engine, windows


def resumable(controller, monkeypatch):
    controller.state["controller"] = {"state": "ready", "pid": 123, "generation": "same", "epoch": controller.epoch}
    controller._save()
    monkeypatch.setattr(windows, "process_generation", lambda pid: "same")


@pytest.mark.parametrize("action", ["status", "recover"])
def test_lifecycle_observation_never_allocates(engine, action):
    controller, native = engine
    for _ in range(3):
        result = controller.dispatch("tabs", {"scope": A, "action": action})
        assert result["scope_state"] == "unallocated"
        assert result["recovery"]["input_replay_allowed"] is False
    assert native.created == 0
    assert controller.state["windows"] == {}


def test_reply_lost_before_receipt_has_finite_actionable_recovery(engine, monkeypatch):
    controller, native = engine
    resumable(controller, monkeypatch)
    native.fail_create = True
    with pytest.raises(windows.ControlError):
        controller.acquire(A)
    saved = controller.path.read_bytes()
    for action in ["status", "recover"] * 3:
        result = controller.dispatch("tabs", {"scope": A, "action": action})
        assert result["recovery"]["reason"] == "creation_reply_not_retained"
        assert result["recovery"]["recovery_state"] == "owner_reconciliation_required"
        assert result["recovery"]["automatic_recovery_exhausted"] is True
        assert result["recovery"]["retry_allowed"] is False
    assert controller.path.read_bytes() == saved
    assert native.created == 1
    assert len(native.tree) == 2
    assert not any(method == "browsingContext.close" for method, _ in native.calls)


@pytest.mark.parametrize("failure", [TimeoutError, KeyboardInterrupt])
def test_reply_committed_before_caller_interruption_recovers_exact_identity(engine, monkeypatch, failure):
    controller, native = engine
    resumable(controller, monkeypatch)
    original = native._bidi
    def exchange(method, params, *, on_reply=None):
        result = original(method, params, on_reply=on_reply)
        if method == "browsingContext.create":
            assert json.loads(controller.path.read_text())["windows"][A]["context"] == result["context"]
            raise failure("caller died after receipt commit")
        return result
    monkeypatch.setattr(native, "_bidi", exchange)
    with pytest.raises(KeyboardInterrupt if failure is KeyboardInterrupt else windows.ControlError):
        controller.acquire(A)
    resumed = windows.Windows(controller.path, connect=lambda: native)
    for _ in range(3):
        result = resumed.dispatch("tabs", {"scope": A, "action": "recover"})
        assert result["scope_state"] == "open"
        assert result["recovery"]["recovery_state"] == "verified"
    assert native.created == 1
    assert resumed.state["windows"][A]["context"] == "context-1"
    assert resumed.lifecycle(close())["closed"] is True
    assert native.tree[0]["context"] == "owner"


def test_correlated_native_rejection_is_not_transport_uncertainty(engine, monkeypatch):
    controller, native = engine
    original = native._bidi
    class Rejected(RuntimeError):
        native_code = "invalid argument"
    def exchange(method, params, *, on_reply=None):
        if method == "browsingContext.create":
            on_reply({"type": "error", "error": "invalid argument", "message": "private detail not persisted"})
            raise Rejected()
        return original(method, params, on_reply=on_reply)
    monkeypatch.setattr(native, "_bidi", exchange)
    with pytest.raises(windows.ControlError) as error:
        controller.acquire(A)
    assert error.value.code == "FIREFOX_CREATE_REJECTED"
    assert error.value.outcome == "not_started"
    for action in ["status", "recover"] * 2:
        result = controller.dispatch("tabs", {"scope": A, "action": action})
        assert result["recovery"]["reason"] == "native_create_rejected_without_effect"
        assert result["recovery"]["outcome"] == "not_started"
    assert "private detail" not in controller.path.read_text()
    assert native.created == 0
    assert controller.lifecycle(close())["already_closed"] is True


def test_generation_change_reports_bounded_owner_decision_without_native_calls(engine, monkeypatch):
    controller, native = engine
    controller.acquire(A)
    resumable(controller, monkeypatch)
    monkeypatch.setattr(windows, "process_generation", lambda pid: "different")
    resumed = windows.Windows(controller.path, connect=lambda: native)
    before = native.calls.copy()
    for action in ["status", "recover"] * 2:
        result = resumed.dispatch("tabs", {"scope": A, "action": action})
        assert result["recovery"]["reason"] == "native_generation_lost"
        assert result["bidi_available"] is False
    assert native.calls == before
    assert native.created == 1


def test_terminal_hook_can_reconcile_creation_receipt_then_close(engine, monkeypatch):
    controller, native = engine
    resumable(controller, monkeypatch)
    controller.acquire(A)
    other = controller.acquire(B).copy()
    record = controller.state["windows"][A]
    record.update(state="creating", prior_windows=["root"])
    controller._save()
    assert controller.lifecycle(close())["closed"] is True
    assert controller.lifecycle(close())["already_closed"] is True
    assert any(c["context"] == other["context"] for c in native.tree)


def test_actual_adapter_status_and_recover_reach_scoped_nonallocating_route(tmp_path, monkeypatch):
    from test_secure_browser_firefox_ui import load_tool
    from test_firefox_endpoint import Reply
    module, _ = load_tool()
    module.CONTROL_MODE = "firefox-windows-v3"
    module.BRIDGE_TOKEN_FILE = tmp_path / "credential"
    module.BRIDGE_TOKEN_FILE.write_text("synthetic-test-credential-only")
    module.CONTROLLER_STATE_DIR = tmp_path / "locks"
    module._session_env = lambda key: ""
    monkeypatch.setenv("HERMES_KANBAN_BOARD", "agent-requests")
    monkeypatch.setenv("HERMES_KANBAN_TASK", "t_alpha")
    seen = []
    def send(_opener, request, **kw):
        seen.append(json.loads(request.data))
        return Reply(b'{"status":"ok","recovery":{"automatic_recovery_exhausted":true}}')
    monkeypatch.setattr("urllib.request.OpenerDirector.open", send)
    for action in ["status", "recover"]:
        result = json.loads(module.secure_browser_tab_lifecycle_tool({"action": action, "workflow_id": "not-authority"}))
        assert result["recovery"]["automatic_recovery_exhausted"] is True
    assert seen == [{"command": "tabs", "payload": {"action": action, "scope": A}} for action in ["status", "recover"]]


def test_adapter_attempts_one_supported_recovery_and_never_replays_input(tmp_path, monkeypatch):
    from test_secure_browser_firefox_ui import load_tool
    module, _ = load_tool()
    module.CONTROL_MODE = "firefox-windows-v3"
    module.CONTROLLER_STATE_DIR = tmp_path
    calls = []
    def bridge(command, payload):
        calls.append((command, payload))
        if command == "click":
            raise module.FirefoxControlError({"error": "FIREFOX_NATIVE_OUTCOME_UNCERTAIN", "outcome": "uncertain"})
        assert (command, payload) == ("tabs", {"action": "recover"})
        return {"recovery": {"recovery_state": "owner_reconciliation_required", "automatic_recovery_exhausted": True}}
    monkeypatch.setattr(module, "_bridge", bridge)
    result = json.loads(module._safe_call("click", lambda: module._bridge("click", {"action_key": "one-send"})))
    assert result["outcome"] == "uncertain"
    assert result["recovery"]["automatic_recovery_exhausted"] is True
    assert calls == [("click", {"action_key": "one-send"}), ("tabs", {"action": "recover"})]


def test_failed_receipt_fsync_cannot_be_adopted_after_worker_death(engine, monkeypatch):
    controller, native = engine
    resumable(controller, monkeypatch)
    original = controller._save
    def save():
        if controller.state["windows"].get(A, {}).get("context"):
            raise OSError("fixture disk failure before identity commit")
        original()
    monkeypatch.setattr(controller, "_save", save)
    with pytest.raises(windows.ControlError):
        controller.acquire(A)
    resumed = windows.Windows(controller.path, connect=lambda: native)
    result = resumed.dispatch("tabs", {"scope": A, "action": "recover"})
    assert result["recovery"]["reason"] == "creation_reply_not_retained"
    assert native.created == 1


def test_dead_http_client_does_not_cancel_creation_receipt(tmp_path, monkeypatch):
    import importlib.util
    from pathlib import Path
    import socket
    import threading
    from test_firefox_windows import Native
    source = Path(__file__).resolve().parents[3] / "files/firefox-browser/firefox-bridge-server.py"
    spec = importlib.util.spec_from_file_location("creation_http_endpoint", source)
    endpoint = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(endpoint)
    endpoint.LOCK_PATH = tmp_path / "endpoint.lock"
    native = Native()
    controller = windows.Windows(tmp_path / "windows.json", connect=lambda: native)
    entered, release, committed = threading.Event(), threading.Event(), threading.Event()
    original = native._bidi
    def exchange(method, params, *, on_reply=None):
        if method == "browsingContext.create":
            entered.set()
            assert release.wait(3)
            result = original(method, params, on_reply=on_reply)
            committed.set()
            return result
        return original(method, params, on_reply=on_reply)
    monkeypatch.setattr(native, "_bidi", exchange)
    server = endpoint.Server(("127.0.0.1", 0), endpoint.Handler)
    server.windows = controller
    server.bridge_token = "synthetic-fixture-credential-only"
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    raw = json.dumps({"command": "tabs", "payload": {"action": "acquire", "scope": A}}).encode()
    try:
        client = socket.create_connection(server.server_address, timeout=3)
        client.sendall((f"POST {endpoint.API_PATH} HTTP/1.1\r\nHost: fixture\r\nAuthorization: Bearer {server.bridge_token}\r\n"
                        f"Content-Type: application/json\r\nContent-Length: {len(raw)}\r\n\r\n").encode() + raw)
        assert entered.wait(3)
        client.close()
        release.set()
        assert committed.wait(3)
        with controller.operation():
            result = controller.dispatch("tabs", {"scope": A, "action": "recover"})
        assert result["recovery"]["recovery_state"] == "verified"
        assert native.created == 1
        assert controller.lifecycle(close())["closed"] is True
    finally:
        release.set()
        server.shutdown()
        server.server_close()
        thread.join(timeout=3)
