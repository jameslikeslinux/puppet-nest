"""Input dispatch is not visible delivery; retain ownership on uncertain closure."""
import contextlib

import unittest

from test_firefox_ui_bridge import configured_bridge


def check_empty_visible_field(native):
    bridge, desktop, tmp = configured_bridge()
    try:
        bridge.command_tabs({"action": "acquire", "workflow_id": "w"})
        bridge._observe_focused_field = lambda: None
        bridge._native_selector = lambda *args: "field"
        @contextlib.contextmanager
        def driver():
            yield lambda *args: None
        bridge._webdriver = driver
        payload = {"workflow_id": "w", "action_key": "empty", "text": "public draft"}
        if native:
            payload.update(operation="type", selector="#field")
        operation = bridge.command_selector_action if native else bridge.command_type
        first = operation(payload)
        assert first["status"] == "delivery_uncertain"
        assert first["delivery"]["input_sent"] is True
        assert first["delivery"]["visible_value_confirmed"] is False
        assert bridge._load_state()["action_keys"]["empty"]["delivery_state"] != "delivered"
        commands = list(desktop.commands)
        replay = operation(payload)
        assert replay["status"] == "delivery_uncertain"
        assert replay["delivery"]["input_sent"] is False
        assert desktop.commands == commands
    finally:
        tmp.cleanup()


def test_empty_visible_field_never_reports_delivered_or_allows_replay():
    for native in (False, True):
        check_empty_visible_field(native)


def test_readback_failure_cannot_commit_success_before_observation():
    bridge, desktop, tmp = configured_bridge()
    try:
        bridge.command_tabs({"action": "acquire", "workflow_id": "w"})
        def fail():
            raise RuntimeError("observation unavailable")
        bridge._readback = fail
        with unittest.TestCase().assertRaisesRegex(RuntimeError, "observation unavailable"):
            bridge.command_type({"workflow_id": "w", "action_key": "lost", "text": "draft"})
        assert bridge._load_state()["action_keys"]["lost"]["delivery_state"] != "delivered"
    finally:
        tmp.cleanup()


def test_dropped_close_retains_binding_and_refuses_repeated_shortcut():
    bridge, desktop, tmp = configured_bridge()
    try:
        bridge.command_tabs({"action": "acquire", "workflow_id": "w"})
        desktop.tabs[-1]["tab_identity"] = "agent-tab"
        with bridge._locked_state() as state:
            state["workflows"]["w"]["tab_identity"] = "agent-tab"
        commands = []
        bridge._xdotool = lambda *args, **kwargs: commands.append(args) or ""
        result = bridge.command_tabs({"action": "release", "workflow_id": "w"})
        assert result["status"] == "closure_uncertain"
        assert "w" in bridge._load_state()["workflows"]
        assert bridge.command_tabs({"action": "release", "workflow_id": "w"})["status"] == "preserved_uncertain"
        assert commands.count(("key", "--clearmodifiers", "ctrl+w")) == 1
    finally:
        tmp.cleanup()


def test_recover_preserves_abandoned_binding_provenance_and_journals():
    bridge, desktop, tmp = configured_bridge()
    try:
        bridge.command_tabs({"action": "acquire", "workflow_id": "w"})
        before = bridge._load_state()["workflows"]["w"].copy()
        bridge.command_tabs({"action": "recover", "workflow_id": "w"})
        archived = bridge._load_state()["abandoned_bindings"]["w"][0]
        assert all(archived[key] == value for key, value in before.items())
        assert archived["disposition"] == "preserved_unresolved"
        assert len(desktop.tabs) == 2
    finally:
        tmp.cleanup()


def test_exact_entry_and_replacement_require_unchanged_field_and_tab():
    bridge, desktop, tmp = configured_bridge()
    try:
        before = {"identity": "field", "tab_identity": "tab", "value": "AB", "caret": 1}
        after = {**before, "value": "AxB", "caret": 2}
        bridge._observe_focused_field = lambda: after
        assert bridge._confirm_typed_input(before, "x")
        after["value"] = "replacement\n"
        assert bridge._confirm_typed_input(before, "replacement\n", mode="replace")
        after["value"] = "replacement"
        assert not bridge._confirm_typed_input(before, "replacement\n", mode="replace")
        after["value"] = "AxB"
        for key in ("identity", "tab_identity"):
            after[key] = "replacement"
            assert not bridge._confirm_typed_input(before, "x")
            after[key] = before[key]
    finally:
        tmp.cleanup()


def test_duplicate_url_native_mapping_uses_observed_context_without_scan():
    bridge, desktop, tmp = configured_bridge()
    try:
        selected = []
        def command(method, path, data=None):
            if path == "/window/handles":
                return ["background", "visible"]
            if path == "/window":
                if method == "POST":
                    selected.append(data["handle"])
                return "background"
            if path == "/url":
                return desktop.snapshot()["url"]
            if path == "/elements":
                return [{"element-6066-11e4-a52e-4f735466cecf": "field"}]
            if path == "/execute/sync":
                return True
            raise AssertionError(path)
        command.selected_context = lambda snapshot: "visible"
        bridge._wait_for_native_tab = lambda snapshot: None
        assert bridge._native_selector(command, desktop.snapshot(), "#field", True) == "field"
        assert selected == ["visible"]
        command.selected_context = lambda snapshot: "not-a-window"
        with unittest.TestCase().assertRaisesRegex(RuntimeError, "mapping is absent or ambiguous"):
            bridge._native_selector(command, desktop.snapshot(), "#field", True)
        assert selected == ["visible", "background"]
    finally:
        tmp.cleanup()


def test_expiry_only_recovery_reuses_exact_identity_without_tab_growth():
    bridge, desktop, tmp = configured_bridge()
    try:
        desktop.tabs[0]["tab_identity"] = "owner-tab"
        bridge.command_tabs({"action": "acquire", "workflow_id": "w"})
        desktop.tabs[-1]["tab_identity"] = "agent-tab"
        with bridge._locked_state() as state:
            state["workflows"]["w"]["tab_identity"] = "agent-tab"
        for _ in range(4):
            with bridge._locked_state() as state:
                state["workflows"]["w"]["lease_expires_at"] = 0
            assert bridge.command_tabs({"action": "recover", "workflow_id": "w"})["status"] == "recovered_reused_tab"
            assert bridge.command_tabs({"action": "acquire", "workflow_id": "w"})["created_tab"] is False
            assert len(desktop.tabs) == 2
        assert bridge.command_tabs({"action": "release", "workflow_id": "w"})["status"] == "released_closed_owned_tab"
        assert len(desktop.tabs) == 1
    finally:
        tmp.cleanup()


def test_uncertain_action_recovery_retains_provenance_and_blocks_replacement_growth():
    bridge, desktop, tmp = configured_bridge()
    try:
        desktop.tabs[0]["tab_identity"] = "owner-tab"
        bridge.command_tabs({"action": "acquire", "workflow_id": "w"})
        desktop.tabs[-1].update(tab_identity="agent-tab", name="Draft")
        with bridge._locked_state() as state:
            state["workflows"]["w"].update(tab_identity="agent-tab", lease_expires_at=0)
            state["action_keys"]["uncertain"] = {"workflow_id": "w", "created_at": bridge.time.time(),
                                                 "operation": "type", "delivery_state": "delivery_started"}
        assert bridge.command_tabs({"action": "recover", "workflow_id": "w"})["status"] == "recovered_preserved_tab"
        for _ in range(3):
            with unittest.TestCase().assertRaisesRegex(RuntimeError, "unresolved abandoned tab provenance"):
                bridge.command_tabs({"action": "acquire", "workflow_id": "w"})
            bridge.command_tabs({"action": "recover", "workflow_id": "w"})
        assert len(desktop.tabs) == 2
        assert len(bridge._load_state()["abandoned_bindings"]["w"]) == 1
        assert "uncertain" in bridge._load_state()["action_keys"]
    finally:
        tmp.cleanup()


def test_archived_blank_tab_cannot_be_claimed_as_a_new_handoff():
    bridge, desktop, tmp = configured_bridge()
    try:
        desktop.tabs[0]["tab_identity"] = "owner-tab"
        bridge.command_tabs({"action": "acquire", "workflow_id": "w"})
        desktop.tabs[-1]["tab_identity"] = "uncertain-blank"
        with bridge._locked_state() as state:
            state["workflows"]["w"].update(tab_identity="uncertain-blank", uncertain=True)
        bridge.command_tabs({"action": "recover", "workflow_id": "w"})
        with unittest.TestCase().assertRaisesRegex(RuntimeError, "unresolved abandoned tab provenance"):
            bridge.command_tabs({"action": "acquire", "workflow_id": "w"})
        assert len(desktop.tabs) == 2
    finally:
        tmp.cleanup()


def test_native_confirmation_requires_dom_ax_and_active_element_agreement():
    bridge, desktop, tmp = configured_bridge()
    try:
        desktop.tabs[0]["tab_identity"] = "owner-tab"
        bridge.command_tabs({"action": "acquire", "workflow_id": "w"})
        desktop.tabs[-1]["tab_identity"] = "agent-tab"
        with bridge._locked_state() as state:
            state["workflows"]["w"]["tab_identity"] = "agent-tab"
        bridge._native_selector = lambda *args: "field"
        state = {"value": "old", "active": "field", "ax": "new"}
        def command(method, path, data=None):
            if path.endswith("/property/value"):
                return state["value"]
            if path == "/element/active":
                return {"element-6066-11e4-a52e-4f735466cecf": state["active"]}
            raise AssertionError(path)
        @contextlib.contextmanager
        def driver():
            yield command
        bridge._webdriver = driver
        bridge._native_type = lambda *args, **kwargs: state.update(value="new")
        bridge._observe_focused_field = lambda: {"identity": "field", "tab_identity": "agent-tab", "value": state["ax"]}
        payload = {"workflow_id": "w", "operation": "type", "mode": "replace", "selector": "#note", "text": "new"}
        assert bridge.command_selector_action({**payload, "action_key": "confirmed"})["status"] == "delivered"
        state.update(value="old", ax="")
        assert bridge.command_selector_action({**payload, "action_key": "empty-ax"})["status"] == "delivery_uncertain"
        state.update(value="old", ax="new", active="other-field")
        assert bridge.command_selector_action({**payload, "action_key": "wrong-active"})["status"] == "delivery_uncertain"
        assert "new" not in bridge.STATE_PATH.read_text()
    finally:
        tmp.cleanup()


if __name__ == "__main__":
    tests = [value for name, value in list(globals().items()) if name.startswith("test_")]
    for test in tests:
        test()
    print(f"{len(tests)} input confirmation tests passed")
