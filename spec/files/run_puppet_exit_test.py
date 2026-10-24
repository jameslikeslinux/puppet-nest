#!/usr/bin/env python3
"""Run the real managed wrapper with disposable command fakes, never Puppet."""

from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/run_puppet.sh"
FAKE = '''#!/bin/sh
printf '%s\\n' "${0##*/} $*" >> "$FIXTURE_CALLS"
case "${0##*/}" in
  uname) printf '%s\\n' Linux ;;
  puppet) exit "$FIXTURE_EXIT" ;;
  systemctl) exit 1 ;;
  flock) exit 0 ;;
  *) exit 99 ;;
esac
'''


class NativePuppetExitTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="nest-puppet-exit-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.calls = self.root / "calls"
        for name in ("uname", "puppet", "systemctl", "flock"):
            path = self.root / name
            path.write_text(FAKE)
            path.chmod(0o700)

    def invoke(self, native, preserve=None):
        self.calls.write_text("")
        env = {"PATH": str(self.root), "FIXTURE_CALLS": str(self.calls),
               "FIXTURE_EXIT": str(native), "PUPPET_AGENT_LOCK_FILE": str(self.root / "lock")}
        if preserve is not None:
            env["PUPPET_PRESERVE_DETAILED_EXIT"] = preserve
        result = subprocess.run(["/bin/sh", str(SCRIPT)], env=env, capture_output=True, text=True, timeout=10)
        return result, self.calls.read_text().splitlines()

    def test_legacy_and_explicit_false_keep_zero_two_success_mapping(self):
        for preserve in (None, "false"):
            for native in (0, 1, 2, 4, 6, 37):
                with self.subTest(preserve=preserve, native=native):
                    result, calls = self.invoke(native, preserve)
                    self.assertEqual(result.returncode, 0 if native == 2 else native)
                    self.assertEqual(calls.count("puppet agent --test"), 1)

    def test_opt_in_retains_every_native_exit_without_implicit_repeat(self):
        for native in (0, 1, 2, 4, 6, 37):
            with self.subTest(native=native):
                result, calls = self.invoke(native, "true")
                self.assertEqual(result.returncode, native)
                self.assertEqual(calls.count("puppet agent --test"), 1)
                self.assertEqual(sum(call.startswith("flock -n ") for call in calls), 1)

    def test_malformed_selection_refuses_before_service_or_lock_commands(self):
        for preserve in ("TRUE", " true", "1"):
            with self.subTest(preserve=preserve):
                result, calls = self.invoke(0, preserve)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(calls, [])
                self.assertFalse((self.root / "lock").exists())


if __name__ == "__main__":
    unittest.main()
