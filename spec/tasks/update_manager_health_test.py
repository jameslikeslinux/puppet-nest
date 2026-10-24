"""The real collector with disposable command/process inventories, never host mutation."""

import importlib.util
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
TASK = Path(__file__).resolve().parents[2] / "tasks" / "update_manager_health.py"
spec = importlib.util.spec_from_file_location("update_manager_health", TASK)
assert spec is not None and spec.loader is not None
health = importlib.util.module_from_spec(spec)
spec.loader.exec_module(health)
BOOT = "12345678-1234-1234-1234-123456789abc"


def unit(name, active="active", sub="running"):
    return {"unit": name, "load": "loaded", "active": active, "sub": sub,
            "description": "private description sentinel"}


class Fixture:
    def __init__(self, managers=None, system=None, user=None):
        self.managers = [unit("user@1000.service")] if managers is None else managers
        self.system = [] if system is None else system
        self.user = {} if user is None else user
        self.calls = []

    def __call__(self, args):
        self.calls.append(args)
        if args[0] == "user-fixture":
            value = self.user.get(int(args[1]), [])
        elif "--state=failed" in args:
            value = self.system
        else:
            value = self.managers
        if isinstance(value, Exception):
            raise value
        return json.dumps(value)


class ManagerHealthTest(unittest.TestCase):
    def collect(self, fixture=None, processes=None, prefix=None, boot=None):
        return health.collect(fixture or Fixture(), processes or (lambda: {1000: 42}),
                              prefix or (lambda uid: ["user-fixture", str(uid)]), boot or (lambda: BOOT))

    def test_actual_user_manager_even_without_login_session(self):
        runner = Fixture()
        result = self.collect(runner)
        self.assertEqual(result["result"], "pass")
        self.assertFalse(result["acceptance_recorded"])
        self.assertEqual(result["user_managers"]["managers"][0]["identity"], "user@1000.service")
        self.assertTrue(any(args[0] == "user-fixture" for args in runner.calls))
        self.assertNotIn("private description sentinel", json.dumps(result))
        self.assertTrue(all("list-units" in args for args in runner.calls))

    def test_empty_only_with_available_complete_process_and_unit_inventories(self):
        result = self.collect(Fixture(managers=[]), processes=lambda: {})
        self.assertEqual(result["user_managers"]["result"], "pass")
        self.assertTrue(result["user_managers"]["inventory_complete"])
        self.assertEqual(result["user_managers"]["managers"], [])

    def test_missing_bus_or_timeout_never_becomes_zero(self):
        for reason in ("user_bus_unavailable", "command_failed", "command_unavailable"):
            result = self.collect(Fixture(user={1000: health.Unavailable(reason)}))
            self.assertEqual(result["result"], "fail")
            self.assertEqual(result["user_managers"]["availability"], "unavailable")
            self.assertFalse(result["user_managers"]["inventory_complete"])
            self.assertNotIn("failures", result["user_managers"]["managers"][0])

    def test_process_unit_disagreement_refuses_inventory(self):
        for pids in ({}, {1001: 43}, {1000: 42, 1001: 43}):
            result = self.collect(processes=lambda: pids)
            self.assertFalse(result["user_managers"]["inventory_complete"])
            self.assertEqual(result["result"], "fail")

    def test_changing_manager_pid_refuses_acceptance(self):
        observations = iter(({1000: 42}, {1000: 43}))
        result = self.collect(processes=lambda: next(observations))
        self.assertEqual(result["user_managers"]["reason"], "user_manager_inventory_changed")
        self.assertEqual(result["result"], "fail")

    def test_boot_change_refuses_entire_observation(self):
        observations = iter((BOOT, "22345678-1234-1234-1234-123456789abc"))
        with self.assertRaisesRegex(health.Unavailable, "boot_changed"):
            self.collect(boot=lambda: next(observations))

    def test_all_actual_managers_are_queried(self):
        runner = Fixture(managers=[unit("user@1001.service"), unit("user@1000.service")],
                         user={1000: health.Unavailable("user_bus_unavailable")})
        result = self.collect(runner, processes=lambda: {1000: 42, 1001: 43})
        self.assertEqual(len(result["user_managers"]["managers"]), 2)
        self.assertEqual(result["user_managers"]["managers"][1]["availability"], "available")
        self.assertEqual(result["result"], "fail")

    def test_failed_system_and_user_identities_retained_not_cleared_or_explained(self):
        result = self.collect(Fixture(system=[unit("old.service", "failed", "failed")],
                                      user={1000: [unit("app.service", "failed", "failed")]}))
        self.assertEqual(result["system_failures"]["failures"][0]["identity"], "old.service")
        self.assertEqual(result["user_managers"]["managers"][0]["failures"][0]["identity"], "app.service")
        self.assertEqual(result["result"], "fail")
        self.assertNotIn("explained_historical", json.dumps(result))

    def test_unavailable_system_inventory_not_zero(self):
        result = self.collect(Fixture(system=health.Unavailable("command_failed")))
        self.assertFalse(result["system_failures"]["inventory_complete"])
        self.assertNotIn("failures", result["system_failures"])
        self.assertEqual(result["result"], "fail")

    def test_system_failure_appearing_during_user_collection_is_not_green(self):
        runner = Fixture()
        def run(args):
            if args[0] == "user-fixture":
                runner.system = [unit("new.service", "failed", "failed")]
            return runner(args)
        result = self.collect(run)
        self.assertEqual(result["result"], "fail")
        self.assertFalse(result["system_failures"]["inventory_complete"])
        self.assertEqual(result["system_failures"]["reason"], "system_failure_inventory_changed")
        self.assertEqual(result["system_failures"]["failures_after"][0]["identity"], "new.service")

    def test_user_failure_change_during_other_manager_collection_is_not_green(self):
        runner = Fixture(managers=[unit("user@1000.service"), unit("user@1001.service")])
        def run(args):
            if args[:2] == ["user-fixture", "1001"]:
                runner.user[1000] = [unit("new-app.service", "failed", "failed")]
            return runner(args)
        result = self.collect(run, processes=lambda: {1000: 42, 1001: 43})
        self.assertEqual(result["result"], "fail")
        self.assertFalse(result["user_managers"]["inventory_complete"])
        manager = result["user_managers"]["managers"][0]
        self.assertEqual(manager["reason"], "user_failure_inventory_changed")
        self.assertEqual(manager["failures_after"][0]["identity"], "new-app.service")

    def test_disappearing_failure_retains_both_observations_without_explanation(self):
        runner = Fixture(system=[unit("old.service", "failed", "failed")])
        def run(args):
            if args[0] == "user-fixture":
                runner.system = []
            return runner(args)
        result = self.collect(run)
        self.assertEqual(result["system_failures"]["failures"][0]["identity"], "old.service")
        self.assertEqual(result["system_failures"]["failures_after"], [])
        self.assertFalse(result["system_failures"]["inventory_complete"])
        self.assertEqual(result["result"], "fail")

    def test_second_system_failure_query_unavailable_is_not_green(self):
        runner = Fixture()
        def run(args):
            if args[0] == "user-fixture":
                runner.system = health.Unavailable("command_failed")
            return runner(args)
        result = self.collect(run)
        self.assertEqual(result["result"], "fail")
        self.assertEqual(result["system_failures"]["availability"], "unavailable")
        self.assertEqual(result["system_failures"]["failures"], [])

    def test_second_user_failure_query_unavailable_is_not_green(self):
        runner = Fixture()
        def run(args):
            value = runner(args)
            if args[0] == "user-fixture":
                runner.user[1000] = health.Unavailable("command_failed")
            return value
        result = self.collect(run)
        self.assertEqual(result["result"], "fail")
        self.assertFalse(result["user_managers"]["inventory_complete"])
        self.assertEqual(result["user_managers"]["managers"][0]["failures"], [])

    def test_disappearing_user_failure_is_retained_and_unavailable(self):
        runner = Fixture(user={1000: [unit("old-app.service", "failed", "failed")]})
        def run(args):
            value = runner(args)
            if args[0] == "user-fixture":
                runner.user[1000] = []
            return value
        result = self.collect(run)
        manager = result["user_managers"]["managers"][0]
        self.assertEqual(manager["failures"][0]["identity"], "old-app.service")
        self.assertEqual(manager["failures_after"], [])
        self.assertEqual(manager["availability"], "unavailable")
        self.assertEqual(result["result"], "fail")

    def test_bus_disappearing_at_recheck_is_not_green(self):
        calls = []
        def prefix(uid):
            calls.append(uid)
            if len(calls) > 1:
                raise health.Unavailable("user_bus_unavailable")
            return ["user-fixture", str(uid)]
        result = self.collect(prefix=prefix)
        self.assertEqual(result["result"], "fail")
        manager = result["user_managers"]["managers"][0]
        self.assertFalse(manager["inventory_complete"])
        self.assertEqual(manager["reason"], "user_bus_unavailable")

    def test_actual_command_runner_with_inert_systemctl_processes(self):
        script = '''import json, pathlib, sys
root = pathlib.Path(__file__).parent
args = sys.argv[1:]
with (root / "calls").open("a") as output:
    output.write(json.dumps(args) + "\\n")
assert "list-units" in args
mode = (root / "mode").read_text()
user = "--user" in args
if "--state=failed" not in args:
    value = [{"unit":"user@1000.service","load":"loaded","active":"active","sub":"running"}]
else:
    repeat = (root / ("user-seen" if user else "system-seen")).exists()
    (root / ("user-seen" if user else "system-seen")).touch()
    if repeat and mode == "unavailable" and not user:
        sys.exit(91)
    failed = (mode == "system" and not user and repeat) or (mode == "user" and user and repeat)
    value = [{"unit":"new.service","load":"loaded","active":"failed","sub":"failed"}] if failed else []
print(json.dumps(value))
'''
        for mode in ("stable", "system", "user", "unavailable"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                executable = root / "systemctl"
                executable.write_text("#!" + sys.executable + "\n" + script)
                executable.chmod(0o700)
                (root / "mode").write_text(mode)
                with patch.dict(health.ENV, {"PATH": directory}):
                    result = self.collect(health.Commands(), prefix=lambda uid: ["systemctl", "--user"])
                self.assertEqual(result["result"], "pass" if mode == "stable" else "fail")
                self.assertFalse(result["acceptance_recorded"])
                calls = [json.loads(line) for line in (root / "calls").read_text().splitlines()]
                self.assertEqual(len(calls), 6)
                self.assertTrue(all("list-units" in args for args in calls))

    def test_transitional_failed_duplicate_and_invalid_managers_refuse(self):
        for rows in ([unit("user@1000.service", "activating", "start")],
                     [unit("user@1000.service", "failed", "failed")],
                     [unit("user@1000.service"), unit("user@1000.service")],
                     [unit("not-a-user.service")]):
            self.assertEqual(self.collect(Fixture(managers=rows))["result"], "fail")

    def test_malformed_unloaded_or_excess_inventory_refuses(self):
        for rows in ({}, [{}], [unit("bad unit")], [dict(unit("one.service"), load="not-found")],
                     [unit("x.service")] * 129):
            result = self.collect(Fixture(system=rows))
            self.assertEqual(result["system_failures"]["availability"], "unavailable")
        with self.assertRaises(health.Unavailable):
            health.units(lambda _: "not json", ["systemctl"])

    def test_inactive_dead_unit_is_not_an_operational_manager(self):
        result = self.collect(Fixture(managers=[unit("user@1000.service", "inactive", "dead")]), processes=lambda: {})
        self.assertEqual(result["result"], "pass")

    def test_process_inventory_reads_only_systemd_user_argv(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for pid, comm, args in (("42", "systemd", b"/lib/systemd/systemd\0--user\0"),
                                    ("43", "systemd", b"/sbin/init\0"),
                                    ("44", "other", b"private command sentinel")):
                path = root / pid
                path.mkdir()
                (path / "comm").write_text(comm)
                if comm == "systemd":
                    (path / "cmdline").write_bytes(args)
            self.assertEqual(health.manager_processes(root), {root.stat().st_uid: 42})
            (root / "45").mkdir()
            (root / "45/comm").write_text("systemd")
            (root / "45/cmdline").write_bytes(b"systemd\0--user\0")
            with self.assertRaisesRegex(health.Unavailable, "ambiguous_user"):
                health.manager_processes(root)

    def test_subprocess_timeout_and_nonzero_are_bounded_and_do_not_leak(self):
        command = health.Commands()
        with patch.object(health.subprocess, "run", side_effect=subprocess.TimeoutExpired("sentinel", 5)):
            with self.assertRaisesRegex(health.Unavailable, "command_unavailable"):
                command(["systemctl"])
        with patch.object(health.subprocess, "run", return_value=subprocess.CompletedProcess([], 1, b"sentinel", b"sentinel")):
            with self.assertRaisesRegex(health.Unavailable, "command_failed"):
                command(["systemctl"])
        command.deadline = 0
        with self.assertRaisesRegex(health.Unavailable, "collection_deadline"):
            command(["systemctl"])

    def test_real_stdin_bad_input_cannot_leak(self):
        result = subprocess.run([sys.executable, str(TASK)], input='{"secret":"private sentinel"}',
                                text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 1)
        self.assertIn("_error", json.loads(result.stdout))
        self.assertNotIn("private sentinel", result.stdout + result.stderr)

    def test_user_bus_requires_existing_owned_socket_and_private_runtime(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            runtime = root / str(os.getuid())
            runtime.mkdir(mode=0o700)
            with patch.object(health, "Path", return_value=root):
                with self.assertRaisesRegex(health.Unavailable, "user_bus_unavailable"):
                    health.user_prefix(os.getuid())
                bus = socket.socket(socket.AF_UNIX)
                try:
                    bus.bind(str(runtime / "bus"))
                    prefix = health.user_prefix(os.getuid())
                    self.assertEqual(prefix[:2], ["runuser", "-u"])
                    self.assertIn("XDG_RUNTIME_DIR=" + str(runtime), prefix)
                    self.assertEqual(prefix[-2:], ["systemctl", "--user"])
                    runtime.chmod(0o777)
                    with self.assertRaisesRegex(health.Unavailable, "unsafe_user_bus"):
                        health.user_prefix(os.getuid())
                finally:
                    bus.close()

    def test_user_bus_rejects_regular_file_or_symlink(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            runtime = root / str(os.getuid())
            runtime.mkdir(mode=0o700)
            (runtime / "bus").write_text("not a bus")
            with patch.object(health, "Path", return_value=root):
                with self.assertRaisesRegex(health.Unavailable, "unsafe_user_bus"):
                    health.user_prefix(os.getuid())
                (runtime / "bus").unlink()
                (runtime / "bus").symlink_to(root / "not-a-bus")
                with self.assertRaisesRegex(health.Unavailable, "unsafe_user_bus"):
                    health.user_prefix(os.getuid())


if __name__ == "__main__":
    unittest.main()
