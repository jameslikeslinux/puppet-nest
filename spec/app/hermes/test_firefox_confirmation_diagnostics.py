"""Confirmation diagnostics disclose checks, never draft contents or replay input."""
import contextlib

from test_firefox_ui_bridge import configured_bridge


def test_native_diagnostics_distinguish_ax_and_active_element_failure():
    bridge, desktop, tmp = configured_bridge()
    try:
        bridge.command_tabs({"action": "acquire", "workflow_id": "w"})
        desktop.tabs[-1]["tab_identity"] = "agent-tab"
        with bridge._locked_state() as state:
            state["workflows"]["w"]["tab_identity"] = "agent-tab"
        bridge._native_selector = lambda *args: "field"
        observation = {"ax": "", "active": "field"}
        draft = "private diagnostic fixture"
        def command(method, path, data=None):
            if path.endswith("/property/value"):
                return draft
            if path == "/element/active":
                return {"element-6066-11e4-a52e-4f735466cecf": observation["active"]}
            raise AssertionError(path)
        @contextlib.contextmanager
        def driver():
            yield command
        bridge._webdriver = driver
        bridge._native_type = lambda *args, **kwargs: None
        bridge._observe_focused_field = lambda: {"value": observation["ax"], "tab_identity": "agent-tab"}
        payload = {"workflow_id": "w", "operation": "type", "mode": "replace", "selector": "#note", "text": draft}
        result = bridge.command_selector_action({**payload, "action_key": "ax-mismatch"})
        checks = result["delivery"]["confirmation"]
        assert result["status"] == "delivery_uncertain"
        assert checks == {"route": "native_element", "mode": "replace", "expectation_available": True,
                          "ax_observed": True, "ax_value_matches": False, "tab_identity_matches": True,
                          "native_active_matches": None, "native_value_matches": None}
        assert bridge._load_state()["action_keys"]["ax-mismatch"]["confirmation"] == checks
        observation.update(ax=draft, active="other-field")
        result = bridge.command_selector_action({**payload, "action_key": "active-mismatch"})
        assert result["delivery"]["confirmation"]["native_active_matches"] is False
        assert result["delivery"]["confirmation"]["native_value_matches"] is True
        calls = []
        bridge._native_type = lambda *args, **kwargs: calls.append(args)
        replay = bridge.command_selector_action({**payload, "action_key": "ax-mismatch"})
        assert replay["delivery"]["confirmation"] == checks
        assert replay["delivery"]["input_sent"] is False
        assert not calls
        assert draft not in bridge.STATE_PATH.read_text()
        assert "#note" not in bridge.STATE_PATH.read_text()
    finally:
        tmp.cleanup()


def test_accessibility_diagnostics_retain_missing_before_and_tab_mismatch():
    bridge, desktop, tmp = configured_bridge()
    try:
        bridge.command_tabs({"action": "acquire", "workflow_id": "w"})
        before = {"identity": "field", "tab_identity": "tab", "value": "", "caret": 0}
        after = {**before, "value": "private diagnostic fixture", "tab_identity": "other-tab"}
        observations = iter([before, after])
        bridge._observe_focused_field = lambda: next(observations)
        payload = {"workflow_id": "w", "text": after["value"], "action_key": "tab-mismatch"}
        result = bridge.command_type(payload)
        checks = result["delivery"]["confirmation"]
        assert checks == {"route": "accessibility", "mode": "insert", "before_observed": True,
                          "after_observed": True, "field_identity_matches": True,
                          "tab_identity_matches": False, "value_matches": True}
        assert result["status"] == "delivery_uncertain"
        assert bridge._load_state()["action_keys"]["tab-mismatch"]["confirmation"] == checks
        bridge._observe_focused_field = lambda: None
        result = bridge.command_type({**payload, "action_key": "unobservable"})
        checks = result["delivery"]["confirmation"]
        assert checks["before_observed"] is False
        assert checks["after_observed"] is False
        assert checks["value_matches"] is None
        replay = bridge.command_type(payload)
        assert replay["delivery"]["confirmation"]["tab_identity_matches"] is False
        assert replay["delivery"]["input_sent"] is False
        assert after["value"] not in bridge.STATE_PATH.read_text()
    finally:
        tmp.cleanup()


if __name__ == "__main__":
    tests = [value for name, value in list(globals().items()) if name.startswith("test_")]
    for test in tests:
        test()
    print(f"{len(tests)} confirmation diagnostic tests passed")
