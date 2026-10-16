"""Browser chrome must not be confused with ARIA tab widgets."""
from types import SimpleNamespace
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from test_firefox_ui_bridge import load_bridge
from test_secure_browser_firefox_ui import load_tool


class Node:
    def __init__(self, role, name="", children=(), selected=False):
        self.role, self.name = role, name
        self.children, self.selected = list(children), selected
        self.path = f"/org/a11y/atspi/accessible/{id(self)}"
        self.app = SimpleNamespace(bus_name=":1.10")

    def get_role_name(self):
        return self.role

    def get_name(self):
        return self.name

    def get_description(self):
        return ""

    def get_child_count(self):
        return len(self.children)

    def get_child_at_index(self, index):
        return self.children[index]


def desktop(windows=1, selected_tabs=1):
    module = load_bridge()
    page_tabs = [Node("page tab", name, selected=index == 0)
                 for index, name in enumerate(("General access rules", "Tailscale SSH", "Auto approvers"))]
    browser_tabs = [Node("page tab", "Policies", selected=True) for _ in range(selected_tabs)]
    frames = [Node("frame", children=[
        Node("tool bar", children=[Node("page tab list", children=browser_tabs)]),
        Node("internal frame", children=[Node("document web", children=[
            Node("tool bar", children=[Node("page tab list", children=page_tabs)])])]),
    ]) for _ in range(windows)]
    root = Node("application", children=frames)
    module._firefox_root = lambda: root
    module._browser_pid = lambda: 100
    module._state_names = lambda node: ["showing", "visible"] + (["selected"] if node.selected else [])
    module._extent = lambda node: {"x": 0, "y": 0, "width": 10, "height": 10}
    module._text_content = lambda node: ""
    module._firefox_window_id = lambda: "1"
    module._run = lambda *args, **kwargs: SimpleNamespace(stdout=b"Fixture", returncode=0)
    return module, root, browser_tabs, page_tabs


class TabAncestryTests(unittest.TestCase):
    def test_chrome_tabs_exclude_aria_tabs_but_keep_page_controls(self):
        module, _, _, _ = desktop()
        snapshot = module._snapshot()
        self.assertEqual(snapshot["tab_count"], 1)
        self.assertEqual(module._selected_tab(snapshot)["name"], "Policies")
        self.assertEqual(len([node for node in snapshot["nodes"] if node["role"] == "page tab"]), 4)

    def check_ambiguous(self, windows, selected_tabs):
        module, _, _, _ = desktop(windows, selected_tabs)
        snapshot = module._snapshot()
        self.assertEqual(snapshot["tab_count"], windows * selected_tabs)
        self.assertIsNone(module._selected_tab(snapshot))
        with self.assertRaisesRegex(RuntimeError, "absent or ambiguous"):
            module._select_workflow_tab({})

    def test_multiple_real_selected_tabs_refuse_input(self):
        self.check_ambiguous(1, 2)

    def test_multiple_real_windows_refuse_input(self):
        self.check_ambiguous(2, 1)

    def test_workflow_uses_chrome_identity_not_same_named_page_tab(self):
        module, _, browser_tabs, page_tabs = desktop()
        page_tabs[0].name = browser_tabs[0].name
        snapshot = module._snapshot()
        record = {"browser_generation": 100, "tab_identity": module._tab_identity(browser_tabs[0], 100),
                  "tab_name": "Policies", "locator": snapshot["tabs"][0]["locator"]}
        module._select_workflow_tab(record)
        record["tab_identity"] = module._tab_identity(page_tabs[0], 100)
        with self.assertRaisesRegex(RuntimeError, "canonical tab identity"):
            module._select_workflow_tab(record)

    def test_page_tab_rename_rejects_stale_locator_but_chrome_navigation_survives(self):
        module, _, browser_tabs, page_tabs = desktop()
        snapshot = module._snapshot()
        locator = next(node["locator"] for node in snapshot["nodes"] if node["name"] == "General access rules")
        chrome_locator = snapshot["tabs"][0]["locator"]
        page_tabs[0].name = "Different control"
        with self.assertRaisesRegex(ValueError, "stale accessibility locator"):
            module._resolve_locator(locator)
        browser_tabs[0].name = "New page title"
        self.assertIs(module._resolve_locator(chrome_locator)[0], browser_tabs[0])
        module._browser_pid = lambda: 101
        with self.assertRaisesRegex(ValueError, "generation changed"):
            module._resolve_locator(chrome_locator)

    def test_window_focus_never_picks_largest_or_first_window(self):
        module = load_bridge()
        module._run = lambda *args, **kwargs: SimpleNamespace(stdout=b"123\n456\n", returncode=0)
        with self.assertRaisesRegex(RuntimeError, "ambiguous"):
            module._firefox_window_id()

    def test_managed_overlay_executes_in_existing_pod_with_payload_on_stdin(self):
        module, _ = load_tool()
        real_run = subprocess.run
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "bridge.py"
            source.write_text("import json,sys; print(json.dumps({'status':'ok','command':sys.argv[1],'payload':json.load(sys.stdin)}))")
            module.BRIDGE_SOURCE = source

            def run(argv, **kwargs):
                self.assertEqual(argv[:9], ["kubectl", "-n", "ai", "exec", "-i", "deployment/firefox", "-c", "kasm-firefox", "--"])
                self.assertEqual(argv[9:13], ["env", "DISPLAY=:1", "python3", "-c"])
                envelope = json.loads(kwargs["input"])
                self.assertEqual(envelope["source"], source.read_text())
                return real_run(argv[11:], **kwargs)

            with patch.dict(os.environ, {"KUBECONFIG": str(source)}), patch.object(module.subprocess, "run", side_effect=run):
                result = module._bridge("snapshot", {"workflow_id": "fixture"})
            self.assertEqual(result, {"status": "ok", "command": "snapshot", "payload": {"workflow_id": "fixture"}})

    def test_missing_managed_overlay_never_falls_back_to_old_image(self):
        module, _ = load_tool()
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "config"
            config.touch()
            module.BRIDGE_SOURCE = Path(directory) / "missing.py"
            with patch.dict(os.environ, {"KUBECONFIG": str(config)}), patch.object(module.subprocess, "run") as run:
                with self.assertRaisesRegex(RuntimeError, "refusing image fallback"):
                    module._bridge("snapshot", {})
                run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
