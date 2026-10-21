"""Same-session window identity, crash safety and exact broker receipt regressions."""
import importlib.util
import json
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import sys
from types import SimpleNamespace

import pytest

ROOT = Path(__file__).resolve().parents[3]
SPEC = importlib.util.spec_from_file_location("firefox_windows", ROOT / "files/firefox-browser/firefox_windows.py")
windows = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(windows)
A = "kanban:agent-requests:t_alpha"
B = "kanban:agent-requests:t_beta"


class Native:
    def __init__(self):
        self.tree = [{"context": "owner", "clientWindow": "root", "url": "https://same.example/"}]
        self.calls = []
        self.fail_create = False
        self.created = 0

    def _bidi(self, method, payload):
        self.calls.append((method, payload))
        if method == "browsingContext.getTree":
            return {"contexts": self.tree.copy()}
        if method == "browsingContext.create":
            self.created += 1
            cid = f"context-{self.created}"
            self.tree.append({"context": cid, "clientWindow": f"window-{self.created}", "url": "https://same.example/"})
            if self.fail_create:
                raise OSError("response lost after creation")
            return {"context": cid}
        if method == "browsingContext.close":
            self.tree = [c for c in self.tree if c["context"] != payload["context"]]
            return {}
        raise AssertionError(method)


@pytest.fixture
def engine(tmp_path):
    native = Native()
    controller = windows.Windows(tmp_path / "windows.json", connect=lambda: native)
    return controller, native


def close(scope=A, event=42, status="completed"):
    return {"action": "close", "scope": scope, "terminal_event_id": event, "terminal_status": status}


def test_repeated_concurrent_acquire_same_session_distinct_windows(engine):
    controller, native = engine
    with ThreadPoolExecutor(max_workers=4) as pool:
        result = list(pool.map(controller.acquire, [A, B] * 10))
    assert native.created == 2
    assert result[0]["window"] != result[1]["window"]
    assert all(record["context"] == result[index % 2]["context"] for index, record in enumerate(result))
    assert not any(method == "browsingContext.activate" for method, _ in native.calls)
    assert native.tree[0]["clientWindow"] == "root"


def test_response_loss_and_restart_preserve_without_replacement(engine):
    controller, native = engine
    native.fail_create = True
    with pytest.raises(RuntimeError):
        controller.acquire(A)
    with pytest.raises(RuntimeError):
        controller.acquire(A)
    restarted = windows.Windows(controller.path, connect=lambda: native)
    for scope in (A, B):
        with pytest.raises(RuntimeError):
            restarted.acquire(scope)
    assert native.created == 1
    assert len(native.tree) == 2


def test_missing_binding_and_duplicate_urls_never_select_other_context(engine):
    controller, native = engine
    record = controller.acquire(A)
    controller.acquire(B)
    native.tree = [c for c in native.tree if c["context"] != record["context"]]
    with pytest.raises(RuntimeError):
        controller.acquire(A)
    assert native.created == 2
    assert not any(method == "browsingContext.close" for method, _ in native.calls)


def test_exact_terminal_closure_deduplicated_after_restart(engine):
    controller, native = engine
    controller.acquire(A)
    other = controller.acquire(B).copy()
    assert controller.lifecycle(close())["closed"] is True
    assert controller.lifecycle(close())["already_closed"] is True
    restarted = windows.Windows(controller.path, connect=lambda: native)
    assert restarted.lifecycle(close())["already_closed"] is True
    assert any(c["context"] == other["context"] for c in native.tree)
    assert native.tree[0]["context"] == "owner"
    assert len([m for m, _ in native.calls if m == "browsingContext.close"]) == 1
    with pytest.raises(RuntimeError):
        controller.acquire(A)
    with pytest.raises(RuntimeError):
        controller.lifecycle(close(event=43))


@pytest.mark.parametrize("status", ["blocked", "waiting", "review", "parked", "running", "failed_probe"])
def test_nonterminal_never_closes(engine, status):
    controller, native = engine
    controller.acquire(A)
    with pytest.raises(ValueError):
        controller.lifecycle(close(status=status))
    assert len(native.tree) == 2


def test_terminal_before_acquire_is_tombstoned(engine):
    controller, native = engine
    assert controller.lifecycle(close())["already_closed"] is True
    with pytest.raises(RuntimeError):
        controller.acquire(A)
    assert native.created == 0


def test_missing_terminal_identity_cannot_acknowledge_closed_scope(engine):
    controller, _ = engine
    controller.state["windows"][A] = {"state": "closed"}
    with pytest.raises(RuntimeError, match="exact terminal receipt"):
        controller.lifecycle(close())


def test_private_session_endpoint_is_literal_and_loopback_only():
    windows.validate_session_endpoint("session-fixture", "ws://127.0.0.1:9222/session/session-fixture")
    for session, endpoint in [
        ("../escape", "ws://127.0.0.1:9222/session/../escape"),
        ("fixture", "ws://wrong.example:9222/session/fixture"),
        ("fixture", "ws://127.0.0.1:9222/session/other"),
        ("fixture", "ws://127.0.0.1:9222/session/fixture?secret=value"),
    ]:
        with pytest.raises((ValueError, RuntimeError)):
            windows.validate_session_endpoint(session, endpoint)


def test_public_newline_is_shift_enter_not_submit(engine, monkeypatch):
    controller, _ = engine
    calls = []
    monkeypatch.setattr(controller, "_call", lambda method, payload: calls.append((method, payload)))
    controller._text_character("bound-context", "\n")
    assert calls == [("input.performActions", {"context": "bound-context", "actions": [{
        "type": "key", "id": "window-keyboard", "actions": [
            {"type": "keyDown", "value": "\ue008"},
            {"type": "keyDown", "value": "\ue007"},
            {"type": "keyUp", "value": "\ue007"},
            {"type": "keyUp", "value": "\ue008"},
        ]}]})]


@pytest.mark.parametrize("text,multiline", [("first\nsecond", False), ("first\tsecond", True), ("first\rsecond", True), ("\ue007", True)])
def test_invalid_public_control_input_is_rejected_before_action(engine, monkeypatch, text, multiline):
    controller, native = engine
    record = controller.acquire(A)
    monkeypatch.setitem(sys.modules, "secure_browser_local_bidi", SimpleNamespace(
        CdpSession=SimpleNamespace(_bidi_value=lambda value: {
            "protected": False, "editable": True, "multiline": multiline})))
    monkeypatch.setattr(controller, "_function", lambda *args: {"value": [("node", {"sharedId": "element"})]})
    monkeypatch.setattr(controller, "_summary", lambda cid: {"url": "https://same.example/"})
    with pytest.raises(ValueError, match="multiline|control characters"):
        controller._input("type", {"scope": A, "action_key": "invalid-control", "selector": "#draft", "text": text}, record, {})
    assert controller.state["actions"] == {}
    assert not any(method == "input.performActions" for method, _ in native.calls)


def test_foreign_context_moved_into_window_is_preserved(engine):
    controller, native = engine
    record = controller.acquire(A)
    native.tree.append({"context": "unproven", "clientWindow": record["window"]})
    with pytest.raises(RuntimeError):
        controller.lifecycle(close())
    assert not any(m == "browsingContext.close" for m, _ in native.calls)


def test_owner_window_never_closes_or_gets_replaced(engine):
    controller, native = engine
    assert controller.acquire("owner")["context"] == "owner"
    with pytest.raises(ValueError):
        controller.lifecycle(close(scope="owner"))
    assert native.created == 0


def test_exact_integer_event_and_scope_validation(engine):
    controller, _ = engine
    for scope in (None, "", "kanban::t_alpha", "kanban:agent-requests:t_alpha/../t_beta"):
        with pytest.raises(ValueError):
            controller.acquire(scope)
    for value in (True, "42", 0, -1):
        with pytest.raises(ValueError):
            controller.lifecycle(close(event=value))


def test_viewer_capability_has_only_its_own_scope(engine):
    controller, _ = engine
    a = controller.acquire(A)
    b = controller.acquire(B)
    assert controller.viewer_scope(a["viewer"]) == A
    assert controller.viewer_scope(b["viewer"]) == B
    with pytest.raises(ValueError):
        controller.viewer_scope("invalid")
    controller.lifecycle(close())
    with pytest.raises(ValueError):
        controller.viewer_scope(a["viewer"])


def test_owner_scroll_targets_only_capability_window(engine, monkeypatch):
    controller, _ = engine
    record = controller.acquire(A)
    controller.acquire(B)
    calls = []
    monkeypatch.setattr(controller, "_call", lambda method, payload: calls.append((method, payload)))
    monkeypatch.setattr(controller, "_resolve", lambda record: {})
    payload = {"kind": "scroll", "x": 20, "y": 40, "deltaX": 0, "deltaY": 500}
    assert controller.owner_input(record["viewer"], payload)["status"] == "ok"
    assert len(calls) == 1 and calls[0][1]["context"] == record["context"]
    assert calls[0][1]["actions"][0]["actions"][0]["deltaY"] == 500
    for value in [True, float("nan"), 2001, "500"]:
        with pytest.raises(ValueError):
            controller.owner_input(record["viewer"], {**payload, "deltaY": value})
    assert len(calls) == 1


def test_same_session_resume_preserves_exact_native_identity(engine, monkeypatch):
    controller, native = engine
    record = controller.acquire(A).copy()
    controller.state["controller"] = {"state": "ready", "pid": 123, "generation": "same", "epoch": controller.epoch}
    controller._save()
    monkeypatch.setattr(windows, "process_generation", lambda pid: "same")
    restarted = windows.Windows(controller.path, connect=lambda: native)
    assert restarted.acquire(A)["context"] == record["context"]
    assert native.created == 1
    assert restarted.epoch == record["epoch"]
    monkeypatch.setattr(windows, "process_generation", lambda pid: "different")
    changed = windows.Windows(controller.path, connect=lambda: native)
    with pytest.raises(RuntimeError):
        changed.acquire(A)
    with pytest.raises(RuntimeError):
        changed.acquire(B)
    assert native.created == 1


def test_old_uncertain_journal_key_cannot_replay_in_new_window(tmp_path):
    key = "joyride-run11909-luna-test-rollback-type"
    legacy = {"action_keys": {key: {"delivery_state": "delivery_uncertain"}}}
    (tmp_path / "state.json").write_text(json.dumps(legacy))
    controller = windows.Windows(tmp_path / "windows.json")
    with pytest.raises(RuntimeError, match="preserved legacy"):
        controller._input("type", {"scope": A, "action_key": key, "text": "must not replay"}, {}, {})
    assert json.loads((tmp_path / "state.json").read_text()) == legacy
    assert controller.state["actions"] == {}


def test_adapter_scope_is_authoritative_not_workflow_or_payload(tmp_path, monkeypatch):
    from test_secure_browser_firefox_ui import load_tool
    from test_firefox_endpoint import Reply
    module, _ = load_tool()
    module.CONTROL_MODE = "firefox-windows-v3"
    module.BRIDGE_TOKEN_FILE = tmp_path / "token"
    module.BRIDGE_TOKEN_FILE.write_text("synthetic-test-credential-only")
    module._session_env = lambda key: ""
    monkeypatch.setenv("HERMES_KANBAN_BOARD", "agent-requests")
    monkeypatch.setenv("HERMES_KANBAN_TASK", "t_alpha")
    seen = []
    def send(_opener, request, **kw):
        seen.append(json.loads(request.data))
        return Reply(b'{"status":"ok"}')
    monkeypatch.setattr("urllib.request.OpenerDirector.open", send)
    module._bridge("snapshot", {"scope": B})
    assert seen[0]["payload"]["scope"] == A
    monkeypatch.setenv("HERMES_KANBAN_BOARD", "")
    with pytest.raises(RuntimeError, match="authoritative"):
        module._bridge("snapshot", {})
    assert len(seen) == 1
