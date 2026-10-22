#!/usr/bin/env python3
"""Exercise the real Zsh bootstrap helper without SSH, Bolt or network access."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / "bin" / "ci-bolt-module-install"
ZSH = shutil.which("zsh")
STUB = r'''#!/usr/bin/env zsh
printf '%s\n' "${0:t} $*" >> "$FIXTURE_CALLS"
case ${0:t} in
  ssh-agent)
    if [[ $1 == -s ]]; then
      print 'SSH_AGENT_PID=123; export SSH_AGENT_PID;'
    fi
    ;;
  ssh-add) exit "$FIXTURE_KEY_EXIT" ;;
  bolt) exit "$FIXTURE_BOLT_EXIT" ;;
  git) print 'fixture source' ;;
  cat) print 'fixture resolver' ;;
  getent) print '192.0.2.1 fixture.example' ;;
  ip|nc|find) ;;
  *) exit 99 ;;
esac
'''


class BootstrapHelperTest(unittest.TestCase):
    def setUp(self):
        if ZSH is None:
            self.fail("The bootstrap contract requires real Zsh")
        self.temp = tempfile.TemporaryDirectory(prefix="nest-bootstrap-fixture-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        (self.root / ".zshenv").write_text('export PATH="$FIXTURE_BIN:$PATH"\n')
        self.project = self.root / "project"
        self.project.mkdir()
        (self.project / "Puppetfile").write_text("fixture module list\n")
        self.calls = self.root / "calls"
        for command in ("ssh-agent", "ssh-add", "bolt", "git", "cat", "getent", "ip", "nc", "find"):
            path = self.bin / command
            path.write_text(STUB)
            path.chmod(0o755)

    def run_helper(self, bolt_exit=0, key_exit=0):
        env = dict(os.environ, PATH=f"{self.bin}:{os.environ['PATH']}",
                   ZDOTDIR=str(self.root), FIXTURE_BIN=str(self.bin),
                   BOLT_PROJECT=str(self.project), NEST_CI_SSH_KEY="fixture-key-not-a-secret",
                   FIXTURE_CALLS=str(self.calls), FIXTURE_BOLT_EXIT=str(bolt_exit),
                   FIXTURE_KEY_EXIT=str(key_exit))
        # A private zshenv sets the fake PATH after the host's global zshenv.
        return subprocess.run([str(ZSH), str(HELPER)], env=env, text=True,
                              capture_output=True, timeout=20)

    def test_success_lists_modules_and_releases_agent(self):
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("== Installed modules ==", result.stdout)
        self.assertNotIn("failed with status", result.stdout)
        calls = self.calls.read_text().splitlines()
        self.assertEqual(calls.count("bolt module install --log-level debug"), 1)
        self.assertEqual(calls.count("ssh-agent -k"), 1)

    def test_failure_preserves_native_exit_and_runs_diagnostics_before_cleanup(self):
        for native_exit in (1, 37, 128):
            with self.subTest(native_exit=native_exit):
                self.calls.write_text("")
                result = self.run_helper(bolt_exit=native_exit)
                self.assertEqual(result.returncode, native_exit, result.stderr)
                self.assertIn(f"== bolt module install failed with status {native_exit} ==", result.stdout)
                self.assertEqual(result.stdout.count("== Resolver configuration =="), 2)
                self.assertIn("== Bolt project state ==", result.stdout)
                self.assertIn("== Puppetfile summary ==", result.stdout)
                self.assertIn("== Module install remnants ==", result.stdout)
                self.assertNotIn("== Installed modules ==", result.stdout)
                self.assertNotIn("read-only variable", result.stderr)
                calls = self.calls.read_text().splitlines()
                self.assertEqual(calls.count("bolt module install --log-level debug"), 1)
                self.assertEqual(calls[-1], "ssh-agent -k")

    def test_key_setup_failure_never_attempts_module_install(self):
        result = self.run_helper(key_exit=23)
        self.assertEqual(result.returncode, 23, result.stderr)
        calls = self.calls.read_text()
        self.assertNotIn("bolt module install", calls)
        self.assertIn("ssh-agent -k", calls)
        self.assertNotIn("failed with status", result.stdout)


if __name__ == "__main__":
    unittest.main()
