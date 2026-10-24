"""Read-only boot collector regressions using isolated native-output fixtures."""

import copy
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import unittest
from typing import Any
from unittest.mock import patch

sys.dont_write_bytecode = True
TASK = Path(__file__).resolve().parents[2] / "tasks/update_boot_health.py"
spec = importlib.util.spec_from_file_location("update_boot_health", TASK)
assert spec is not None and spec.loader is not None
health = importlib.util.module_from_spec(spec)
spec.loader.exec_module(health)
OLD_BOOT = "12345678-1234-1234-1234-123456789abc"
NEW_BOOT = "22345678-1234-1234-1234-123456789abc"
EXPECTED = dict(hostname="fixture-host", kernel="6.18.57", previous_boot_id=OLD_BOOT,
                current="rpool/crypt/ROOT/B", current_guid="11", var_guid="12", pool_guid="10")
MOUNTS = ("1 0 0:1 / / rw,relatime - zfs rpool/crypt/ROOT/B rw,xattr\n"
          "2 1 0:2 / /var rw,relatime - zfs rpool/crypt/ROOT/B/var rw,xattr\n")


class Fixture:
    def __init__(self):
        self.calls = []
        self.pools = "rpool\t10\tONLINE\nother\t20\tONLINE\n"
        self.bootfs = EXPECTED["current"] + "\n"
        self.properties = ("rpool/crypt/ROOT/B\tguid\t11\n"
                           "rpool/crypt/ROOT/B\tmounted\tyes\n"
                           "rpool/crypt/ROOT/B/var\tguid\t12\n"
                           "rpool/crypt/ROOT/B/var\tmounted\tyes\n")

    def __call__(self, args):
        self.calls.append(args)
        if args[:2] == ["zpool", "list"]:
            return self.pools
        if args[:2] == ["zpool", "get"]:
            return self.bootfs
        if args[:2] == ["zfs", "get"]:
            return self.properties
        raise AssertionError("Unexpected command")


class BootHealthTest(unittest.TestCase):
    def collect(self, runner=None, mounts=None, boot=None, hostname=None, kernel=None, expected=None):
        return health.collect(expected or EXPECTED, runner or Fixture(), mounts or (lambda: MOUNTS),
                              boot or (lambda: NEW_BOOT), hostname or (lambda: "fixture-host"),
                              kernel or (lambda: "6.18.57"))

    def test_exact_boot_kernel_current_next_var_and_all_pools_without_acceptance(self):
        runner = Fixture()
        result = self.collect(runner)
        self.assertEqual(result["result"], "pass")
        self.assertFalse(result["acceptance_recorded"])
        self.assertEqual(result["checks"]["storage"]["observation"]["online_pools"], {"other": "20", "rpool": "10"})
        self.assertEqual(len(runner.calls), 6)
        self.assertTrue(all(args[:2] in (["zpool", "list"], ["zpool", "get"], ["zfs", "get"]) for args in runner.calls))

    def test_unchanged_boot_wrong_host_and_wrong_kernel_are_not_accepted(self):
        for kwargs, gate in ((dict(boot=lambda: OLD_BOOT), "reboot"),
                             (dict(hostname=lambda: "different-host"), "hostname"),
                             (dict(kernel=lambda: "6.12.42"), "kernel")):
            with self.subTest(gate=gate):
                result = self.collect(**kwargs)
                self.assertEqual(result["result"], "fail")
                self.assertEqual(result["checks"][gate]["result"], "fail")

    def test_exact_reviewed_kernel_exception_is_supported_not_hardcoded(self):
        expected = dict(EXPECTED, kernel="6.12.42-vendor")
        self.assertEqual(self.collect(kernel=lambda: expected["kernel"], expected=expected)["result"], "pass")

    def test_stacked_root_or_var_never_passes_even_with_expected_top_mount(self):
        for extra in MOUNTS.splitlines(keepends=True):
            result = self.collect(mounts=lambda: MOUNTS + extra)
            self.assertEqual(result["checks"]["mounts"]["reason"], "missing_or_stacked_mount")
            self.assertEqual(result["result"], "fail")

    def test_wrong_var_and_read_only_or_non_zfs_mount_refuse(self):
        for raw in (MOUNTS.replace("/B/var", "/A/var"), MOUNTS.replace(" rw,relatime", " ro,relatime"),
                    MOUNTS.replace(" - zfs ", " - nfs "), MOUNTS.splitlines()[0] + "\n",
                    MOUNTS.replace("/ /var", "/subtree /var"), MOUNTS.replace(" rw,xattr", " ro,xattr")):
            with self.subTest(raw=raw):
                self.assertEqual(self.collect(mounts=lambda: raw)["result"], "fail")

    def test_mount_change_during_repeat_refuses(self):
        observations = iter((MOUNTS, MOUNTS.replace("/B/var", "/A/var")))
        self.assertEqual(self.collect(mounts=lambda: next(observations))["result"], "fail")

    def test_private_var_child_cannot_hide_a_previous_boot_environment(self):
        child = "3 2 0:3 / /var/lib rw - zfs rpool/crypt/ROOT/A/var/lib rw\n"
        self.assertEqual(self.collect(mounts=lambda: MOUNTS + child)["result"], "fail")
        child = child.replace("ROOT/A", "ROOT/B")
        self.assertEqual(self.collect(mounts=lambda: MOUNTS + child)["result"], "pass")
        self.assertEqual(self.collect(mounts=lambda: MOUNTS + child + child)["result"], "fail")

    def test_storage_acquisition_cannot_hide_later_mount_change(self):
        runner = Fixture()
        def mounts():
            return MOUNTS if not runner.calls else MOUNTS.replace("/B/var", "/A/var")
        self.assertEqual(self.collect(runner, mounts=mounts)["result"], "fail")

    def test_every_pool_must_be_online_and_root_guid_is_exact(self):
        for pools in ("rpool\t10\tONLINE\nother\t20\tDEGRADED\n", "rpool\t99\tONLINE\n",
                      "rpool\t10\tONLINE\nrpool\t10\tONLINE\n", "", "malformed\n"):
            runner = Fixture()
            runner.pools = pools
            self.assertEqual(self.collect(runner)["result"], "fail")

    def test_changed_next_boot_dataset_guids_unmounted_and_extra_properties_refuse(self):
        for change in ("next_boot", "guid", "mounted", "extra"):
            runner = Fixture()
            if change == "next_boot":
                runner.bootfs = EXPECTED["current"].replace("/B", "/A")
            elif change == "guid":
                runner.properties = runner.properties.replace("\t12\n", "\t99\n")
            elif change == "mounted":
                runner.properties = runner.properties.replace("\tyes\n", "\tno\n")
            else:
                runner.properties += "unrelated\tguid\t14\n"
            self.assertEqual(self.collect(runner)["result"], "fail")

    def test_storage_observation_race_refuses(self):
        runner = Fixture()
        def changing(args):
            value = runner(args)
            if len(runner.calls) > 3 and args[:2] == ["zpool", "list"]:
                return value.replace("other\t20", "other\t21")
            return value
        # The full observation must bind all pool GUIDs, including non-root pools.
        self.assertEqual(self.collect(changing)["result"], "fail")

    def test_missing_commands_are_unavailable_never_empty_success(self):
        def absent(_):
            raise health.Unavailable("command_failed")
        result = self.collect(absent)
        self.assertEqual(result["checks"]["storage"]["result"], "unavailable")
        self.assertEqual(result["result"], "fail")

    def test_boot_host_or_kernel_change_during_collection_refuses_entire_report(self):
        for key, values in (("boot", (NEW_BOOT, OLD_BOOT)), ("hostname", ("fixture-host", "other")),
                            ("kernel", ("6.18.57", "6.18.58"))):
            observations = iter(values)
            with self.assertRaisesRegex(health.Unavailable, "boot_identity_changed"):
                self.collect(**{key: lambda: next(observations)})

    def test_malformed_expectations_refuse_before_commands(self):
        for mutate in (lambda e: e.update(extra="private sentinel"), lambda e: e.update(current="rpool/ROOT/A;id"),
                       lambda e: e.update(current="rpool/ROOT/inside/ROOT/B"), lambda e: e.update(kernel="bad kernel"),
                       lambda e: e.update(pool_guid=True), lambda e: e.update(previous_boot_id="unknown"),
                       lambda e: e.update(var_guid=e["current_guid"]), lambda e: e.pop("hostname")):
            expected = copy.deepcopy(EXPECTED)
            mutate(expected)
            runner = Fixture()
            with self.assertRaises(health.Unavailable):
                self.collect(runner, expected=expected)
            self.assertEqual(runner.calls, [])

    def test_timeout_nonzero_output_limit_and_deadline_do_not_leak(self):
        command = health.Commands()
        for outcome in (subprocess.TimeoutExpired("private sentinel", 5),
                        subprocess.CompletedProcess([], 1, b"private sentinel", b"private sentinel"),
                        subprocess.CompletedProcess([], 0, b"x" * (1024 * 1024 + 1), b"")):
            kwargs: dict[str, Any] = {"side_effect": outcome} if isinstance(outcome, Exception) else {"return_value": outcome}
            with patch.object(health.subprocess, "run", **kwargs):
                with self.assertRaises(health.Unavailable) as caught:
                    command(["zpool", "list"])
                self.assertNotIn("private sentinel", str(caught.exception))
        command.deadline = 0
        with self.assertRaisesRegex(health.Unavailable, "collection_deadline"):
            command(["zpool", "list"])

    def test_real_task_stdin_rejects_bad_inputs_without_command_or_private_output(self):
        for raw in ('{"private":"private sentinel"}', "{}", "not json", "x" * 16385):
            result = subprocess.run([sys.executable, str(TASK)], input=raw, text=True, capture_output=True, check=False)
            self.assertEqual(result.returncode, 1)
            self.assertIn("_error", json.loads(result.stdout))
            self.assertNotIn("private sentinel", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
