"""Generic secure-browser safety regressions; no retailer or composer fixtures."""
import contextlib
import json
import subprocess
from unittest.mock import patch

from test_firefox_ui_bridge import configured_bridge
from test_secure_browser_firefox_ui import load_tool
from test_secure_browser_bidi_ui import load


def test_ordinary_type_forwards_retry_key_and_coordinate():
    tool, _ = load_tool()
    calls = []
    tool._bridge = lambda command, payload: calls.append((command, payload)) or {"status": "delivered"}
    args = {"workflow_id": "w", "coordinate": [120, 300], "text": "public text", "action_key": "once"}
    assert json.loads(tool.secure_browser_type_tool(args))["status"] == "delivered"
    assert calls == [("type", {"workflow_id": "w", "locator": None, "coordinate": [120, 300],
                               "text": "public text", "action_key": "once"})]
    calls.clear()
    assert json.loads(tool.secure_browser_type_tool({"text": "public text"}))["status"] == "error"
    assert calls == []


def test_duplicate_titles_and_multiple_selected_tabs_are_not_identity():
    bridge, desktop, tmp = configured_bridge()
    try:
        bridge.command_tabs({"action": "acquire", "workflow_id": "w"})
        desktop.tabs[0]["name"] = "New Tab"
        state = bridge._load_state()
        assert bridge._matching_tabs(desktop.snapshot(), state["workflows"]["w"]) == []
        desktop.tabs[0]["selected"] = True
        assert bridge._selected_tab(desktop.snapshot()) is None
    finally:
        tmp.cleanup()


def test_ambiguous_selected_state_never_sends_input():
    bridge, desktop, tmp = configured_bridge()
    try:
        bridge.command_tabs({"action": "acquire", "workflow_id": "w"})
        desktop.tabs[0]["selected"] = True
        before = list(desktop.commands)
        try:
            bridge.command_type({"workflow_id": "w", "text": "public text", "action_key": "once"})
        except RuntimeError as exc:
            assert "selected" in str(exc)
        else:
            raise AssertionError("ambiguous selected state received input")
        assert desktop.commands == before
    finally:
        tmp.cleanup()


def test_bridge_rejects_unjournaled_typing_before_input():
    bridge, desktop, tmp = configured_bridge()
    try:
        bridge.command_tabs({"action": "acquire", "workflow_id": "w"})
        before = list(desktop.commands)
        try:
            bridge.command_type({"workflow_id": "w", "text": "public text"})
        except ValueError as exc:
            assert "action_key" in str(exc)
        else:
            raise AssertionError("unjournaled typing accepted")
        assert desktop.commands == before
    finally:
        tmp.cleanup()


def test_explicit_recovery_preserves_uncertain_tabs_and_action_journal():
    bridge, desktop, tmp = configured_bridge()
    try:
        bridge.command_tabs({"action": "acquire", "workflow_id": "w"})
        with bridge._locked_state() as state:
            state["workflows"]["w"]["uncertain"] = True
            state["action_keys"]["once"] = {"created_at": bridge.time.time(), "workflow_id": "w",
                                             "operation": "type", "delivery_state": "delivery_started"}
        preserved = list(desktop.tabs)
        result = bridge.command_tabs({"action": "recover", "workflow_id": "w"})
        assert result["status"] == "recovered_preserved_tab"
        assert desktop.tabs == preserved
        assert "w" not in bridge._load_state()["workflows"]
        assert "once" in bridge._load_state()["action_keys"]
        assert not any(c[:3] == ("key", "--clearmodifiers", "ctrl+w") for c in desktop.commands)
    finally:
        tmp.cleanup()


def test_native_selector_uses_post_selection_snapshot():
    bridge, desktop, tmp = configured_bridge()
    try:
        bridge.command_tabs({"action": "acquire", "workflow_id": "w"})
        desktop.tabs[0]["selected"], desktop.tabs[1]["selected"] = True, False
        def select(record):
            desktop.tabs[0]["selected"], desktop.tabs[1]["selected"] = False, True
        bridge._select_workflow_tab = select
        @contextlib.contextmanager
        def driver():
            yield lambda *args: None
        bridge._webdriver = driver
        def selector(command, snapshot, css, field):
            assert snapshot["tabs"][1]["selected"]
            return "public-element"
        bridge._native_selector = selector
        assert bridge.command_selector_action({"workflow_id": "w", "operation": "click",
                                               "selector": "#public", "action_key": "once"})["status"] == "delivered"
    finally:
        tmp.cleanup()


def test_link_observation_executes_with_credential_components_removed():
    module, _ = load()
    script = module._read_script('document.querySelectorAll("a").href')
    source = '''
const links=['https://example.test/avatar.png?signature=PRIVATE#PRIVATE',
 'https://user:PRIVATE@example.test/path', 'javascript:alert(1)',
 'https://example.test/reset/PRIVATE', '/relative?code=PRIVATE'];
const document={baseURI:'https://example.test/',querySelectorAll:()=>links.map(href=>({
 name:'',id:'',labels:[],getAttribute:()=>null,matches:s=>s==='a[href],area[href]',
 querySelector:()=>null,href}))};
'''
    result = subprocess.run(["node", "-e", source + "console.log(JSON.stringify(" + script + "));"],
                            capture_output=True, text=True, check=True)
    values = json.loads(result.stdout)["values"]
    assert values == ["https://example.test", "<redacted>", "<redacted>", "https://example.test", "https://example.test"]
    assert "PRIVATE" not in result.stdout


def test_native_mapping_restores_initial_handle_on_ambiguity():
    bridge, desktop, tmp = configured_bridge()
    try:
        current = "owner"
        sent = []
        def command(method, path, data=None):
            nonlocal current
            if path == "/window/handles":
                return ["owner", "duplicate"]
            if path == "/window" and method == "GET":
                return current
            if path == "/window":
                assert data is not None
                current = data["handle"]
                sent.append(current)
                return None
            if path == "/url":
                return "https://example.test/"
            raise AssertionError("element lookup must not happen")
        try:
            bridge._native_selector(command, desktop.snapshot(), "#public", False)
        except RuntimeError as exc:
            assert "ambiguous" in str(exc)
        else:
            raise AssertionError("ambiguous native mapping accepted")
        assert current == "owner"
        assert sent[-1] == "owner"
    finally:
        tmp.cleanup()


def test_native_typing_supports_inherited_contenteditable():
    bridge, desktop, tmp = configured_bridge()
    try:
        scripts = []
        def command(method, path, data=None):
            if path == "/window/handles":
                return ["visible"]
            if path == "/window":
                return "visible" if method == "GET" else None
            if path == "/url":
                return "https://example.test/"
            if path == "/elements":
                return [{"element-6066-11e4-a52e-4f735466cecf": "editable"}]
            if path == "/execute/sync":
                assert data is not None
                scripts.append(data["script"])
                return True
            raise AssertionError(path)
        bridge._native_selector(command, desktop.snapshot(), "#public", True)
        source = '''
const e={name:'',id:'',labels:[],isContentEditable:true,disabled:false,readOnly:false,
 getAttribute:()=>null,matches:()=>false};
'''
        result = subprocess.run(["node", "-e", source + "console.log((function(){" + scripts[0] + "})(e,true));"],
                                capture_output=True, text=True, check=True)
        assert result.stdout.strip() == "true"
    finally:
        tmp.cleanup()


def test_accessibility_object_identity_survives_rename_and_reorder_not_replacement():
    bridge, desktop, tmp = configured_bridge()
    try:
        record = {"browser_generation": 100, "tab_identity": "opaque-original",
                  "tab_name": "Fixture", "locator": "old"}
        snapshot = {"browser_generation": 100, "tabs": [
            {"name": "Fixture", "locator": "old", "tab_identity": "opaque-replacement"},
            {"name": "Renamed", "locator": "new", "tab_identity": "opaque-original"}]}
        assert bridge._matching_tabs(snapshot, record) == [snapshot["tabs"][1]]
        snapshot["tabs"].pop()
        assert bridge._matching_tabs(snapshot, record) == []
        snapshot["tabs"][0]["tab_identity"] = "opaque-original"
        snapshot["browser_generation"] = 101
        assert bridge._matching_tabs(snapshot, record) == []
    finally:
        tmp.cleanup()


def test_native_typing_paces_characters_and_partial_delivery_is_not_replayed():
    bridge, desktop, tmp = configured_bridge()
    try:
        bridge.command_tabs({"action": "acquire", "workflow_id": "w"})
        sent, pauses = [], []
        bridge._native_selector = lambda *args: "original"
        def command(method, path, data):
            assert bridge._load_state()["action_keys"][key]["delivery_state"] == "delivery_started"
            if path == "/execute/async":
                assert "setTimeout(done, arguments[0])" in data["script"]
                pauses.append(data["args"][0])
                return
            assert (method, path) == ("POST", "/element/original/value")
            if key == "partial" and len(sent) == 1:
                raise RuntimeError("stale element")
            sent.append(data["text"])
        @contextlib.contextmanager
        def webdriver():
            yield command
        bridge._webdriver = webdriver
        payload = {"workflow_id": "w", "operation": "type", "selector": "#note", "text": "Aé🦉"}
        key = "paced"
        assert bridge.command_selector_action({**payload, "action_key": key})["status"] == "delivered"
        assert sent == list(payload["text"]) and pauses == [100] * 3
        assert bridge.command_selector_action({**payload, "action_key": key})["status"] == "already_delivered"
        assert len(sent) == 3
        key = "partial"
        sent.clear()
        try:
            bridge.command_selector_action({**payload, "action_key": key})
        except RuntimeError as exc:
            assert str(exc) == "stale element"
        else:
            raise AssertionError("partial input reported delivered")
        replay = bridge.command_selector_action({**payload, "action_key": key})
        assert replay["status"] == "delivery_uncertain" and not replay["delivery"]["input_sent"]
        assert sent == ["A"]
    finally:
        tmp.cleanup()


def test_coordinate_typing_sends_explicit_returns_without_clearing():
    bridge, desktop, tmp = configured_bridge()
    try:
        bridge._xdotool = lambda *args, **kwargs: "1365 768" if args == ("getdisplaygeometry",) else desktop.xdotool(*args, **kwargs)
        bridge.command_tabs({"action": "acquire", "workflow_id": "w"})
        desktop.commands.clear()
        bridge.command_type({"workflow_id": "w", "coordinate": [120, 300],
                             "text": "First\n\nSecond\n", "action_key": "paragraphs"})
        typed = [command[-1] for command in desktop.commands if command[0] == "type"]
        assert typed == ["First", "Second"]
        assert desktop.commands.count(("key", "--clearmodifiers", "shift+Return")) == 3
        assert not any("ctrl+a" in command for command in desktop.commands)
        before = list(desktop.commands)
        assert bridge.command_type({"workflow_id": "w", "text": "ignored", "action_key": "paragraphs"})["status"] == "already_delivered"
        assert desktop.commands == before
    finally:
        tmp.cleanup()


def test_native_replacement_is_explicit_journaled_and_not_retried():
    bridge, desktop, tmp = configured_bridge()
    try:
        bridge.command_tabs({"action": "acquire", "workflow_id": "w"})
        sent = []
        bridge._native_selector = lambda *args: "original"
        def command(method, path, data):
            assert bridge._load_state()["action_keys"][key]["delivery_state"] == "delivery_started"
            if path == "/execute/async":
                return
            assert (method, path) == ("POST", "/element/original/value")
            sent.append(data["text"])
            if key == "partial" and len(sent) == 2:
                raise RuntimeError("delivery interrupted")
        @contextlib.contextmanager
        def webdriver():
            yield command
        bridge._webdriver = webdriver
        payload = {"workflow_id": "w", "operation": "type", "selector": "#note", "text": "A\n\nB", "mode": "replace"}
        key = "replace"
        assert bridge.command_selector_action({**payload, "action_key": key})["status"] == "delivered"
        assert sent == ["\ue009a\ue000", "A", "\n", "\n", "B"]
        before = list(sent)
        assert bridge.command_selector_action({**payload, "action_key": key})["status"] == "already_delivered"
        assert sent == before
        sent.clear()
        key = "partial"
        try:
            bridge.command_selector_action({**payload, "action_key": key})
        except RuntimeError:
            pass
        else:
            raise AssertionError("interrupted replacement reported delivered")
        before = list(sent)
        assert bridge.command_selector_action({**payload, "action_key": key})["status"] == "delivery_uncertain"
        assert sent == before
    finally:
        tmp.cleanup()


def test_native_scan_waits_for_matching_chrome_url_without_reselecting():
    bridge, desktop, tmp = configured_bridge()
    try:
        expected = desktop.snapshot()
        observed = [{**expected, "url": "https://other.test/"}, expected]
        reads, selections = [], []
        def snapshot():
            reads.append(True)
            return observed.pop(0) if observed else expected
        bridge._snapshot = snapshot
        def command(method, path, data=None):
            if path == "/window/handles":
                return ["fixture"]
            if path == "/window":
                if method == "POST":
                    assert data is not None
                    selections.append(data["handle"])
                return "fixture"
            if path == "/url":
                return expected["url"]
            if path == "/elements":
                assert len(reads) >= 2
                return [{"element-6066-11e4-a52e-4f735466cecf": "public"}]
            if path == "/execute/sync":
                return True
            raise AssertionError(path)
        assert bridge._native_selector(command, expected, "#public", True) == "public"
        assert selections == ["fixture", "fixture"]
    finally:
        tmp.cleanup()


def test_native_scan_settling_rejects_changed_generation_or_object():
    bridge, desktop, tmp = configured_bridge()
    try:
        expected = desktop.snapshot()
        for current in (
            {**expected, "browser_generation": 101},
            {**expected, "tabs": [{"name": expected["tabs"][0]["name"], "selected": True, "locator": "different-object"}]},
        ):
            bridge._snapshot = lambda: current
            with patch.object(bridge.time, "monotonic", side_effect=[0, 4]):
                try:
                    bridge._wait_for_native_tab(expected)
                except RuntimeError:
                    pass
                else:
                    raise AssertionError("changed browser/tab accepted while settling")
        assert desktop.commands == []
    finally:
        tmp.cleanup()


def test_adapter_replacement_only_accepts_guarded_selector_and_forwards_mode():
    tool, _ = load_tool()
    calls = []
    tool._bridge = lambda command, payload: calls.append((command, payload)) or {"status": "ok", "tabs": []}
    args = {"workflow_id": "w", "text": "exact\n\nparagraphs", "action_key": "replace", "mode": "replace"}
    assert json.loads(tool.secure_browser_type_tool(args))["status"] == "error"
    assert calls == []
    tool.CONTROL_MODE = "firefox-bidi-ui-v2"
    assert json.loads(tool.secure_browser_type_tool({**args, "coordinate": [1, 2]}))["status"] == "error"
    assert calls == []
    assert json.loads(tool.secure_browser_type_tool({**args, "selector": "#note"}))["status"] == "ok"
    assert calls[-1][1]["mode"] == "replace"
    calls.clear()
    assert json.loads(tool.secure_browser_type_tool({**args, "selector": "#note", "mode": "typo"}))["status"] == "error"
    assert calls == []


if __name__ == "__main__":
    tests = [(name, fn) for name, fn in list(globals().items()) if name.startswith("test_")]
    for name, fn in tests:
        fn()
        print("PASS", name)
    print(f"{len(tests)} generic secure-browser regressions passed")
