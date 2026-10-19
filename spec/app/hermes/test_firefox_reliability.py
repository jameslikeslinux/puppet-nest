"""Regressions for the persistent Firefox controller lifecycle."""
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
import tempfile
import threading
from unittest.mock import patch

SPEC = spec_from_file_location("bridge_fixtures", Path(__file__).with_name("test_firefox_ui_bridge.py"))
assert SPEC and SPEC.loader
fixtures = module_from_spec(SPEC)
SPEC.loader.exec_module(fixtures)


def test_acquisition_waits_for_delayed_selection_without_repeating_shortcut():
    module, desktop, temporary = fixtures.configured_bridge()
    original = desktop.snapshot
    pending = []
    original_input = desktop.xdotool

    def deliver(*args, **kwargs):
        if args == ("key", "--clearmodifiers", "ctrl+t"):
            pending.append(original())
        return original_input(*args, **kwargs)

    def snapshot():
        return pending.pop(0) if pending else original()

    module._snapshot = snapshot
    module._xdotool = deliver
    try:
        with patch.object(module.time, "sleep"):
            result = module.command_tabs({"action": "acquire", "workflow_id": "delayed"})
        assert result["created_tab"]
        assert len(desktop.tabs) == 2
        assert desktop.commands.count(("key", "--clearmodifiers", "ctrl+t")) == 1
    finally:
        temporary.cleanup()


def test_process_generation_changes_when_pid_is_reused():
    module = fixtures.load_bridge()
    module._browser_pid = lambda: 62
    # /proc stat field 22 is starttime; the command may contain spaces or ')'.
    def proc(start):
        return "62 (firefox browser) S " + " ".join(["0"] * 18 + [str(start)] + ["0"] * 8)
    with patch.object(module.Path, "read_text", side_effect=[proc(100), "boot-a", proc(200), "boot-a"]), patch.object(module.os, "stat") as stat:
        stat.return_value.st_ino = 400
        first = module._browser_generation()
        second = module._browser_generation()
    assert first != second


def test_non_text_accessibles_never_invoke_text_interface():
    module = fixtures.load_bridge()
    class Node:
        def get_interfaces(self):
            return ["Accessible", "Component"]
    with patch.object(module.importlib, "import_module") as imported:
        assert module._text_content(Node()) == ""
        imported.assert_not_called()


def test_two_workflows_cannot_claim_the_same_blank_tab():
    module, desktop, temporary = fixtures.configured_bridge()
    desktop.tabs = [{"name": "New Tab", "selected": True}]
    try:
        module.command_tabs({"action": "acquire", "workflow_id": "first"})
        module.command_tabs({"action": "acquire", "workflow_id": "second"})
        records = module._load_state()["workflows"]
        assert records["first"]["locator"] != records["second"]["locator"]
        assert len(desktop.tabs) == 2
    finally:
        temporary.cleanup()


def test_supported_controller_serializes_complete_operations():
    spec = spec_from_file_location("adapter_fixtures", Path(__file__).with_name("test_secure_browser_firefox_ui.py"))
    assert spec and spec.loader
    helper = module_from_spec(spec)
    spec.loader.exec_module(helper)
    module, _ = helper.load_tool()
    entered = threading.Event()
    release = threading.Event()
    second_entered = threading.Event()
    with tempfile.TemporaryDirectory() as directory:
        module.CONTROLLER_STATE_DIR = Path(directory)
        def first_callback():
            entered.set()
            assert release.wait(3)
            return {"status": "ok"}
        def second_callback():
            second_entered.set()
            return {"status": "ok"}
        first = threading.Thread(target=module._safe_call, args=("query", first_callback))
        second = threading.Thread(target=module._safe_call, args=("type", second_callback))
        first.start()
        assert entered.wait(1)
        second.start()
        try:
            assert not second_entered.wait(.2)
        finally:
            release.set()
            first.join(3)
            second.join(3)
        assert second_entered.is_set()


def test_diagnostics_do_not_walk_accessibility_or_read_profile_content():
    module = fixtures.load_bridge()
    module._browser_pid = lambda: 62
    module._browser_generation = lambda: "opaque-generation"
    fields = ["0"] * 30
    fields[0] = "S"
    with patch.object(module.Path, "read_text", return_value="62 (firefox) " + " ".join(fields)), patch.object(module, "_snapshot", side_effect=AssertionError("page read")):
        result = module.command_diagnostics({})
    assert result["page_or_profile_content_read"] is False
    assert result["browser_generation"] == "opaque-generation"
    assert not any(key in result for key in ("title", "url", "tabs", "nodes"))


if __name__ == "__main__":
    for name in sorted(name for name in globals() if name.startswith("test_")):
        globals()[name]()
