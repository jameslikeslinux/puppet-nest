#!/usr/bin/env python3
"""Profile isolation and immutable registration contract for Talon's prompt plugin."""

import importlib.util
from pathlib import Path
import sys

import unittest
from unittest.mock import Mock, patch


PLUGIN_DIR = Path(__file__).resolve().parents[3] / "files/app/hermes/talon_operational_prompt_plugin"


class TalonOperationalPromptTest(unittest.TestCase):
    def setUp(self):
        # Hermes is a deployment dependency, not a dependency of Nest's tests.
        constants = Mock()
        constants.get_hermes_home = Mock(return_value=Path("/profiles/talon"))
        profiles = Mock()
        profiles.get_active_profile_name = Mock(return_value="talon")
        with patch.dict(sys.modules, {"hermes_constants": constants, "hermes_cli.profiles": profiles}):
            spec = importlib.util.spec_from_file_location("talon_prompt_test", PLUGIN_DIR / "__init__.py")
            assert spec and spec.loader
            self.plugin = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(self.plugin)
        self.plugin.__file__ = "/profiles/talon/plugins/talon-operational-prompt/__init__.py"
        self.ctx = Mock()

    def test_registers_one_bounded_static_section(self):
        expected = (PLUGIN_DIR / "readable-prose.md").read_text().strip()
        with patch.object(Path, "read_text", return_value=expected) as read:
            self.plugin.register(self.ctx)
        read.assert_called_once_with(encoding="utf-8")
        self.ctx.register_system_prompt_section.assert_called_once_with(
            "talon.readable-prose", expected, position="after_memory", max_chars=2048,
        )
        self.assertIn("tool arguments, request/context/subject fields", expected)
        self.assertIn("Preserve opaque identifiers, hashes, URLs, paths and commands exactly", expected)

    def test_other_profiles_never_read_or_register_even_with_inherited_environment(self):
        for name in ("star", "beryl", "quill", "default", "custom"):
            with self.subTest(profile=name), patch.dict("os.environ", {"HERMES_PROFILE": "talon"}):
                self.plugin.get_active_profile_name.return_value = name
                with patch.object(Path, "read_text") as read:
                    self.plugin.register(self.ctx)
                read.assert_not_called()
        self.ctx.register_system_prompt_section.assert_not_called()

    def test_project_or_other_home_copy_is_not_accepted(self):
        self.plugin.__file__ = "/project/.hermes/plugins/talon-operational-prompt/__init__.py"
        with patch.object(Path, "read_text") as read:
            self.plugin.register(self.ctx)
        read.assert_not_called()
        self.ctx.register_system_prompt_section.assert_not_called()

    def test_missing_asset_is_an_explicit_load_failure(self):
        with patch.object(Path, "read_text", side_effect=FileNotFoundError):
            with self.assertRaises(FileNotFoundError):
                self.plugin.register(self.ctx)
        self.ctx.register_system_prompt_section.assert_not_called()

    def test_empty_and_oversized_assets_are_explicit_load_failures(self):
        for content in (" \n", "x" * 2049):
            with self.subTest(length=len(content)), patch.object(Path, "read_text", return_value=content):
                with self.assertRaises(ValueError):
                    self.plugin.register(self.ctx)
        self.ctx.register_system_prompt_section.assert_not_called()


if __name__ == "__main__":
    unittest.main()
