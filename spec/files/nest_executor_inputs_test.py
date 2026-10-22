#!/usr/bin/env python3
"""Exercise real local module trees/Git only; no network, containers or OS build."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/nest-executor-inputs.py"
BASE = "registry.example/nest/tools/bolt@sha256:" + "f" * 64


class ExecutorInputsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.project = Path(self.temp.name) / "project"
        self.project.mkdir()
        self.env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1",
                        PYTHONDONTWRITEBYTECODE="1")
        self.git(self.project, "init", "-b", "main")
        self.git(self.project, "config", "user.name", "Fixture")
        self.git(self.project, "config", "user.email", "fixture@example.invalid")
        (self.project / "scripts").mkdir()
        shutil.copyfile(SCRIPT, self.project / "scripts/nest-executor-inputs.py")
        (self.project / "Puppetfile").write_text("# Fixture only\n")
        self.git(self.project, "add", "Puppetfile", "scripts")
        self.git(self.project, "commit", "-m", "Fixture source")
        self.source = self.git(self.project, "rev-parse", "HEAD")
        modules = self.project / ".modules"
        modules.mkdir()
        self.git(self.project, "clone", str(self.project), str(modules / "nest"))
        for name in ("stdlib", "reboot", "ruby_task_helper", "private", "kubecm"):
            module = modules / name
            module.mkdir()
            (module / "fixture").write_text("fixture-only-private-content")

    def git(self, path, *args):
        return subprocess.check_output(["git", "-C", str(path), *args], env=self.env,
                                       stderr=subprocess.DEVNULL, text=True).strip()

    def cli(self, action, **changes):
        result = subprocess.run([sys.executable, str(SCRIPT), action, "--project", str(self.project),
                                 "--source", changes.get("source", self.source), "--base", changes.get("base", BASE)],
                                env=self.env, text=True, capture_output=True, check=False)
        self.assertNotIn("fixture-only-private-content", result.stdout + result.stderr)
        return result

    def record(self):
        result = self.cli("record")
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_real_inventory_record_and_read_only_check(self):
        row = self.record()
        before = (self.project / ".executor-inputs.json").read_bytes()
        result = self.cli("check")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), row)
        self.assertEqual(row["source"], self.source)
        self.assertEqual(row["base_image"], BASE)
        self.assertEqual(len(row["modules"]), 6)
        self.assertEqual((self.project / ".executor-inputs.json").read_bytes(), before)
        self.assertEqual(self.cli("record").returncode, 1)
        self.assertEqual((self.project / ".executor-inputs.json").read_bytes(), before)

    def test_changed_bytes_names_mode_and_link_text_are_not_accepted(self):
        self.record()
        module = self.project / ".modules/stdlib"
        path = module / "fixture"
        for change in (lambda: path.write_text("different"), lambda: path.chmod(0o755),
                       lambda: path.rename(module / "renamed"), lambda: (module / "link").symlink_to("fixture")):
            change()
            self.assertEqual(self.cli("check").returncode, 1)
            if (module / "renamed").exists():
                (module / "renamed").rename(path)
            if (module / "link").is_symlink():
                (module / "link").unlink()
            path.write_text("fixture-only-private-content")
            path.chmod(0o644)
        self.assertEqual(self.cli("check").returncode, 0)

    def test_missing_added_or_external_module_refuses(self):
        self.record()
        module = self.project / ".modules/stdlib"
        module.rename(self.project / "saved")
        self.assertEqual(self.cli("check").returncode, 1)
        module.symlink_to(self.project / "saved", target_is_directory=True)
        self.assertEqual(self.cli("check").returncode, 1)
        module.unlink()
        (self.project / "saved").rename(module)
        (self.project / ".modules/extra").mkdir()
        (self.project / ".modules/extra/file").write_text("fixture")
        self.assertEqual(self.cli("check").returncode, 1)

    def test_wrong_source_base_nested_source_and_dirty_source_refuse(self):
        self.assertEqual(self.cli("record", source="b" * 40).returncode, 1)
        self.assertEqual(self.cli("record", base="nest/tools/bolt:latest").returncode, 1)
        nested = self.project / ".modules/nest"
        (nested / "Puppetfile").write_text("changed")
        self.assertEqual(self.cli("record").returncode, 1)
        self.git(nested, "checkout", "--", "Puppetfile")
        (self.project / "Puppetfile").write_text("changed")
        self.assertEqual(self.cli("record").returncode, 1)
        self.assertFalse((self.project / ".executor-inputs.json").exists())

    def test_record_corruption_and_symlink_are_not_accepted(self):
        self.record()
        path = self.project / ".executor-inputs.json"
        original = path.read_bytes()
        path.write_bytes(original + b" ")
        self.assertEqual(self.cli("check").returncode, 1)
        path.unlink()
        other = self.project / "other"
        other.write_bytes(original)
        path.symlink_to(other)
        self.assertEqual(self.cli("check").returncode, 1)

    def test_containerfile_pins_nested_module_from_local_source_when_branch_moves(self):
        nested = self.project / ".modules/nest"
        self.git(nested, "config", "user.name", "Fixture")
        self.git(nested, "config", "user.email", "fixture@example.invalid")
        (nested / "Puppetfile").write_text("Moved nested module")
        self.git(nested, "commit", "-am", "Moved nested branch")
        # Bolt prunes tracked non-module content in both index and worktree.
        (nested / "scripts/nest-executor-inputs.py").unlink()
        self.git(nested, "rm", "--cached", "Puppetfile")
        command = next(line[4:] for line in (ROOT / "Containerfile").read_text().splitlines()
                       if line.startswith('RUN git -C "$BOLT_PROJECT/.modules/nest"'))
        result = subprocess.run(["sh", "-c", command], env=dict(self.env, BOLT_PROJECT=str(self.project),
                                SOURCE_SHA=self.source, BOLT_IMAGE=BASE), capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.git(nested, "rev-parse", "HEAD"), self.source)
        self.assertEqual(self.cli("check").returncode, 0)


    def test_installer_pruned_git_modules_are_content_bound_but_modifications_refuse(self):
        module = self.project / ".modules/reboot"
        self.git(module, "init", "-b", "main")
        self.git(module, "config", "user.name", "Fixture")
        self.git(module, "config", "user.email", "fixture@example.invalid")
        (module / "docs").write_text("Pruned installer fixture")
        (module / "spec").write_text("Pruned fixture index")
        self.git(module, "add", ".")
        self.git(module, "commit", "-m", "Fixture module")
        (module / "docs").unlink()
        self.git(module, "rm", "spec")
        self.record()
        self.assertEqual(self.cli("check").returncode, 0)
        self.git(module, "restore", "--source=HEAD", "--staged", "--worktree", ".")
        self.assertEqual(self.cli("check").returncode, 1, "Changed installed content must not match its old digest")
        (self.project / ".executor-inputs.json").unlink()
        (module / "fixture").write_text("Changed tracked source")
        self.assertEqual(self.cli("record").returncode, 1)


if __name__ == "__main__":
    unittest.main()
