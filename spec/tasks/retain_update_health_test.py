"""Real stdin publication of native collector fixtures; never live host commands."""

import copy
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.dont_write_bytecode = True
TASKS = Path(__file__).resolve().parents[2] / "tasks"
sys.path.insert(0, str(TASKS))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import retain_update_health as retainer
import update_boot_health_test as boot_fixture
import update_manager_health_test as manager_fixture
import update_network_health_test as network_fixture

EXPECTED = boot_fixture.EXPECTED
BOOT = boot_fixture.NEW_BOOT
ENDPOINTS = [network_fixture.ENDPOINT]
TRANSACTION = "fixture-cycle"
RELEASE = "sha256:" + "b" * 64


def fixture(system=None, user=None, endpoints=None, processes=None):
    before = retainer.boot.collect(EXPECTED, boot_fixture.Fixture(), mounts=lambda: boot_fixture.MOUNTS,
                                   boot=lambda: BOOT, hostname=lambda: "fixture-host", kernel=lambda: "6.18.57")
    with mock.patch.object(manager_fixture.health.socket, "gethostname", return_value="fixture-host"):
        managers = manager_fixture.health.collect(manager_fixture.Fixture(system=system, user=user),
                                                   processes=processes or (lambda: {1000: 42}),
                                                   prefix=lambda uid: ["user-fixture", str(uid)], boot=lambda: BOOT)
    client = retainer.network.collect(endpoints, network_fixture.Fixture(), boot=lambda: BOOT,
                                     hostname=lambda: "fixture-host") if endpoints else None
    healthy = all(row["result"] == "pass" for row in ([before, managers, client] if client else [before, managers]))
    return {"schema": 1, "kind": "nest_update_health", "result": "pass" if healthy else "fail", "observations_bound": True,
            "boot_before": before, "managers": managers, "network": client, "network_requested": bool(endpoints),
            "boot_after": copy.deepcopy(before), "acceptance_recorded": False}


class RetainHealthTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name).resolve()
        self.worker = self.root / "worker"
        self.supervisor = self.root / "supervisor"
        self.worker.mkdir()
        self.supervisor.mkdir()

    def tearDown(self):
        self.temp.cleanup()

    def arguments(self, value=None, endpoints=None):
        return {"action": "retain", "expectations": EXPECTED, "endpoints": endpoints or [],
                "transaction": TRANSACTION, "release": RELEASE, "output_dir": str(self.supervisor),
                "report": json.dumps(fixture(endpoints=endpoints) if value is None else value)}

    def run_task(self, params):
        return subprocess.run([sys.executable, str(TASKS / "retain_update_health.py")], input=json.dumps(params),
                              text=True, capture_output=True, cwd=self.worker, check=False, timeout=30)

    def project(self, value, endpoints=None):
        return retainer.project(json.dumps(value), EXPECTED, endpoints or [], TRANSACTION, RELEASE)

    def test_real_collector_shape_stdin_readback_survives_worker_removal(self):
        params = self.arguments(endpoints=ENDPOINTS)
        result = self.run_task(params)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        receipt = json.loads(result.stdout)
        path = Path(receipt["path"])
        raw = path.read_bytes()
        self.assertEqual(path.parent, self.supervisor)
        self.assertEqual(receipt["sha256"], hashlib.sha256(raw).hexdigest())
        self.assertEqual(receipt["bytes"], len(raw))
        self.assertEqual(path.stat().st_mode & 0o777, 0o644)
        self.assertTrue(receipt["readback_verified"])
        shutil.rmtree(self.worker)
        report = json.loads(path.read_bytes())
        self.assertEqual(report["result"], "pass")
        self.assertFalse(report["acceptance_recorded"])
        self.assertFalse(report["preparation_verified"])
        self.assertEqual(report["expectations"], EXPECTED)
        self.assertEqual(report["transport_sha256"], hashlib.sha256(params["report"].encode()).hexdigest())
        self.assertNotIn("private description sentinel", raw.decode())
        self.assertNotIn("/var", json.dumps(report["boot_before"]))

    def test_preflight_creates_nothing_and_checks_all_context(self):
        params = self.arguments()
        params.pop("report")
        params["action"] = "check"
        self.assertEqual(self.run_task(params).returncode, 0)
        self.assertEqual(list(self.supervisor.iterdir()), [])
        for key, value in (("transaction", "bad/path"), ("release", "sha256:bad"),
                           ("expectations", dict(EXPECTED, current_guid="0")), ("endpoints", [{}])):
            with self.subTest(key=key):
                self.assertEqual(self.run_task(dict(params, **{key: value})).returncode, 1)

    def test_missing_or_symlink_destination_refuses_without_creation(self):
        for destination in (self.root / "missing", self.root / "alias"):
            if destination.name == "alias":
                destination.symlink_to(self.supervisor, target_is_directory=True)
            params = self.arguments()
            params["output_dir"] = str(destination)
            self.assertEqual(self.run_task(params).returncode, 1)
        self.assertFalse((self.root / "missing").exists())

    def test_unavailable_bus_is_preserved_not_zero(self):
        value = fixture(user={1000: manager_fixture.health.Unavailable("user_bus_unavailable")})
        result = self.project(value)
        self.assertEqual(result["result"], "fail")
        manager = result["managers"]["user_managers"]["managers"][0]
        self.assertEqual(manager["identity"], "user@1000.service")
        self.assertFalse(manager["inventory_complete"])
        self.assertEqual(manager["reason"], "user_bus_unavailable")
        self.assertNotIn("failures", manager)
        self.assertEqual(self.run_task(self.arguments(value)).returncode, 0)

    def test_historical_failure_identity_is_retained_without_clearing_or_accepting(self):
        value = fixture(system=[manager_fixture.unit("historic.service", "failed", "failed")])
        result = self.project(value)
        self.assertEqual(result["result"], "fail")
        self.assertEqual(result["managers"]["system_failures"]["failures"],
                         [{"identity": "historic.service", "active": "failed", "sub": "failed"}])
        self.assertFalse(result["acceptance_recorded"])

    def test_changed_failure_inventory_preserves_both_samples(self):
        value = fixture()
        system = value["managers"]["system_failures"]
        system.update(availability="unavailable", inventory_complete=False, result="fail",
                      reason="system_failure_inventory_changed", failures_after=[{"identity": "new.service", "active": "failed", "sub": "failed"}])
        value["managers"]["result"] = value["result"] = "fail"
        result = self.project(value)["managers"]["system_failures"]
        self.assertEqual(result["failures"], [])
        self.assertEqual(result["failures_after"][0]["identity"], "new.service")
        self.assertEqual(result["result"], "fail")

    def test_changed_manager_inventory_retains_failure(self):
        value = fixture(processes=lambda: {})
        result = self.project(value)
        self.assertEqual(result["result"], "fail")
        self.assertEqual(result["managers"]["user_managers"]["reason"], "unit_process_inventory_mismatch")

    def test_no_requested_network_stays_unobserved(self):
        result = self.project(fixture())
        self.assertIsNone(result["network"])
        self.assertEqual(result["endpoints"], [])
        self.assertFalse(result["preparation_verified"])

    def test_unavailable_network_and_nonmatching_status_remain_failures(self):
        for unavailable in (True, False):
            value = fixture(endpoints=ENDPOINTS)
            row = value["network"]["endpoints"][0]
            row["result"] = value["network"]["result"] = value["result"] = "fail"
            if unavailable:
                value["network"]["endpoints"] = [{"hostname": ENDPOINTS[0]["hostname"], "availability": "unavailable",
                                                    "result": "fail", "reason": "command_unavailable"}]
            else:
                row["https"]["status"] = 503
            self.assertEqual(self.project(value, ENDPOINTS)["network"]["result"], "fail")
            self.assertEqual(self.run_task(self.arguments(value, ENDPOINTS)).returncode, 0)

    def test_cross_boot_and_changed_brackets_are_retained_only_as_unbound_failure(self):
        for part in ("managers", "boot_after", "network"):
            value = fixture(endpoints=ENDPOINTS)
            value[part]["boot_id"] = "32345678-1234-1234-1234-123456789abc"
            value.update(observations_bound=False, result="fail")
            result = self.project(value, ENDPOINTS)
            self.assertFalse(result["observations_bound"])
            self.assertEqual(result["result"], "fail")
            self.assertEqual(self.run_task(self.arguments(value, ENDPOINTS)).returncode, 0)

    def test_concurrent_equal_publication_is_idempotent_and_conflicting_bytes_are_preserved(self):
        params = self.arguments()
        children = [subprocess.Popen([sys.executable, str(TASKS / "retain_update_health.py")], stdin=subprocess.PIPE,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) for _ in range(2)]
        receipts = []
        for child in children:
            out, err = child.communicate(json.dumps(params), timeout=30)
            self.assertEqual(child.returncode, 0, out + err)
            receipts.append(json.loads(out))
        self.assertEqual(receipts[0], receipts[1])
        path = Path(receipts[0]["path"])
        path.write_text("conflicting bytes")
        self.assertEqual(self.run_task(params).returncode, 1)
        self.assertEqual(path.read_text(), "conflicting bytes")

    def test_outcome_and_identity_corruption_cannot_be_promoted(self):
        mutations = [(("schema",), True), (("acceptance_recorded",), True), (("observations_bound",), False),
                     (("result",), "fail"), (("boot_before", "schema"), True), (("boot_before", "boot_id"), "bad"),
                     (("boot_before", "checks", "reboot", "result"), "fail"),
                     (("managers", "user_managers", "inventory_complete"), False),
                     (("managers", "system_failures", "result"), "fail"),
                     (("managers", "user_managers", "managers", 0, "uid"), True),
                     (("managers", "user_managers", "managers", 0, "pid"), 0),
                     (("network_requested",), True)]
        for path, replacement in mutations:
            with self.subTest(path=path):
                value = fixture()
                target = value
                for key in path[:-1]:
                    target = target[key]
                target[path[-1]] = replacement
                self.assertEqual(self.run_task(self.arguments(value)).returncode, 1)
        self.assertEqual(list(self.supervisor.iterdir()), [])

    def test_private_extra_fields_are_not_copied_and_private_reason_refuses(self):
        value = fixture()
        value["managers"]["raw_command"] = "private payload sentinel"
        value["boot_before"]["checks"]["mounts"]["observation"]["private"] = "private payload sentinel"
        value["boot_after"] = copy.deepcopy(value["boot_before"])
        result = self.project(value)
        self.assertNotIn("private payload sentinel", json.dumps(result))
        value["managers"]["system_failures"]["reason"] = "private error with spaces"
        result = self.run_task(self.arguments(value))
        self.assertEqual(result.returncode, 1)
        self.assertNotIn("private error", result.stdout + result.stderr)

    def test_duplicate_oversized_noop_and_invalid_json_refuse_without_publication(self):
        params = self.arguments()
        for raw in ('{"schema":1,"schema":1}', "x" * 262145, "null", "[]", "{"):
            self.assertEqual(self.run_task(dict(params, report=raw)).returncode, 1)
        self.assertEqual(self.run_task(dict(params, _noop=True)).returncode, 1)
        self.assertEqual(list(self.supervisor.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
