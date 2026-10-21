"""No host or ZFS mutation: exercise the actual stdin task across filesystems."""


import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.dont_write_bytecode = True
TASK = Path(__file__).resolve().parents[2] / "tasks" / "retain_update_report.py"
spec = importlib.util.spec_from_file_location("retain_update_report", TASK)
assert spec is not None and spec.loader is not None
retainer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(retainer)


def fixture(state="prepared", schema=1):
    tree = [{"dataset": "fixture/crypt/ROOT/A", "guid": "101", "mountpoint": "/"}]
    boot = "12345678-1234-1234-1234-123456789abc"
    return {
        "schema": schema, "kind": "reset_transaction_report", "id": "fixture-report", "state": state,
        "release": "sha256:" + "a" * 64, "success": True,
        "accepted": schema == 2, "finalized": state == "finalized", "reboot_requested": False,
        "host": {"hostname": "fixture-host", "boot_id": boot, "pool_guid": "100",
                 "current": "fixture/crypt/ROOT/A", "target": "fixture/crypt/ROOT/B",
                 "next_boot": "fixture/crypt/ROOT/A", "current_tree": tree},
        "host_identity_sha256": "b" * 64,
        "shared_state": {"dataset": "fixture/crypt/nest-updates", "guid": "102", "pool_guid": "100"},
        "source": {"path": "/fixture/releases/one", "dataset": "fixture/releases/one", "guid": "103",
                   "creation_txg": "104", "release": "sha256:" + "a" * 64},
        "policy": {"filter_sha256": "c" * 64, "cli_sha256": "d" * 64},
        "target_tree": [{"dataset": "fixture/crypt/ROOT/B", "guid": "105", "mountpoint": "/"}],
        "phases": [{"phase": phase, "state": "complete", "attempt": 1, "boot_id": boot,
                    "started_at": "2026-10-21T20:00:00Z", "finished_at": "2026-10-21T20:01:00Z",
                    "native_exit": None, "commands": []} for phase in retainer.PHASES],
    }


class RetainUpdateReportTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name).resolve()
        self.worker = self.root / "worker"
        self.supervisor = self.root / "supervisor"
        self.worker.mkdir()
        self.supervisor.mkdir()

    def tearDown(self):
        self.temp.cleanup()

    def arguments(self, data=None):
        return {"report": json.dumps(data or fixture()), "transaction": "fixture-report",
                "release": "sha256:" + "a" * 64, "hostname": "fixture-host", "output_dir": str(self.supervisor)}

    def run_task(self, arguments):
        return subprocess.run([sys.executable, str(TASK)], input=json.dumps(arguments), text=True,
                              capture_output=True, cwd=self.worker, check=False)

    def test_real_stdin_transport_reopen_and_worker_removal(self):
        source = self.worker / "remote-stdout.json"
        source.write_text(json.dumps(fixture()))
        arguments = self.arguments()
        arguments["report"] = source.read_text()
        result = self.run_task(arguments)
        self.assertEqual(result.returncode, 0, result.stdout)
        receipt = json.loads(result.stdout)
        path = Path(receipt["path"])
        self.assertEqual(path.parent, self.supervisor)
        self.assertTrue(receipt["readback_verified"])
        self.assertEqual(receipt["sha256"], hashlib.sha256(path.read_bytes()).hexdigest())
        self.assertEqual(receipt["phase_count"], 6)
        self.assertEqual(path.stat().st_mode & 0o777, 0o644)
        shutil.rmtree(self.worker)
        self.assertEqual(json.loads(path.read_text())["state"], "prepared")

    def test_unknown_payload_fields_cannot_leak(self):
        data = fixture()
        data["environment"] = {"SECRET": "private sentinel"}
        data["host"]["machine_id"] = "private sentinel"
        data["phases"][0]["stdout"] = "private sentinel"
        data["acceptance"] = {"raw_journal": "private sentinel"}
        result = self.run_task(self.arguments(data))
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertNotIn("private sentinel", Path(json.loads(result.stdout)["path"]).read_text())

    def test_mismatched_binding_or_schema_cannot_publish(self):
        for key, value in (("transaction", "wrong"), ("release", "sha256:" + "b" * 64), ("hostname", "wrong")):
            arguments = self.arguments()
            arguments[key] = value
            self.assertEqual(self.run_task(arguments).returncode, 1)
        data = fixture()
        data["schema"] = True
        self.assertEqual(self.run_task(self.arguments(data)).returncode, 1)
        self.assertEqual(list(self.supervisor.iterdir()), [])

    def test_incomplete_or_invalid_phase_cannot_claim_prepared(self):
        for change in ("order", "missing", "failed", "boot", "native", "success"):
            data = fixture()
            if change == "order":
                data["phases"].reverse()
            elif change == "missing":
                data["phases"].pop()
            elif change == "failed":
                data["phases"][-1]["state"] = "failed"
            elif change == "boot":
                data["phases"][0]["boot_id"] = "wrong"
            elif change == "native":
                data["phases"][0]["native_exit"] = True
            else:
                data["phases"][0]["commands"] = [{"operation": "root", "native_exit": 1, "success": False}]
            with self.subTest(change=change):
                self.assertEqual(self.run_task(self.arguments(data)).returncode, 1)

    def test_partial_stopped_and_lifecycle_are_distinct(self):
        for state, schema in (("stopped", 1), ("accepted", 2), ("finalizing", 2), ("finalized", 2)):
            data = fixture(state, schema)
            if state == "stopped":
                data["phases"] = data["phases"][:2]
                data["phases"][-1]["state"] = "failed"
                data["phases"][-1]["native_exit"] = 17
                data["success"] = False
                data["target_tree"] = None
            result = self.run_task(self.arguments(data))
            self.assertEqual(result.returncode, 0, result.stdout)
            receipt = json.loads(result.stdout)
            self.assertEqual(receipt["state"], state)
            self.assertEqual(receipt["cli_accepted"], schema == 2)
            retained = json.loads(Path(receipt["path"]).read_text())
            self.assertFalse(retained["acceptance_independently_verified"])

    def test_bad_input_error_does_not_repeat_private_payload(self):
        args = self.arguments()
        for raw in ("private sentinel", "{}", "[]", "x" * 262145):
            args["report"] = raw
            result = self.run_task(args)
            self.assertEqual(result.returncode, 1)
            self.assertNotIn("private sentinel", result.stdout + result.stderr)
            self.assertIn("_error", json.loads(result.stdout))

    def test_missing_or_symlink_destination_is_refused(self):
        args = self.arguments()
        args["output_dir"] = str(self.root / "missing")
        self.assertEqual(self.run_task(args).returncode, 1)
        link = self.root / "link"
        link.symlink_to(self.supervisor)
        args["output_dir"] = str(link)
        self.assertEqual(self.run_task(args).returncode, 1)
        self.assertEqual(list(self.supervisor.iterdir()), [])

    def test_identical_repeat_and_concurrent_publication_are_idempotent(self):
        args = self.arguments()
        processes = [subprocess.Popen([sys.executable, str(TASK)], stdin=subprocess.PIPE,
                                      stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) for _ in range(2)]
        receipts = []
        for process in processes:
            stdout, stderr = process.communicate(json.dumps(args))
            self.assertEqual(process.returncode, 0, stderr + stdout)
            receipts.append(json.loads(stdout))
        self.assertEqual(receipts[0], receipts[1])
        self.assertEqual(len(list(self.supervisor.glob("*.json"))), 1)
        args["report"] = json.dumps(fixture("accepted", 2))
        self.assertEqual(self.run_task(args).returncode, 0)
        self.assertEqual(len(list(self.supervisor.glob("*.json"))), 2)

    def test_publish_failure_preserves_prior_report(self):
        args = self.arguments()
        first = json.loads(self.run_task(args).stdout)
        prior = Path(first["path"]).read_bytes()
        report = retainer.project(json.dumps(fixture("accepted", 2)), args["transaction"], args["release"], args["hostname"])
        with mock.patch.object(retainer.os, "link", side_effect=OSError("injected")):
            with self.assertRaises(OSError):
                retainer.publish(report, self.supervisor)
        self.assertEqual(Path(first["path"]).read_bytes(), prior)
        self.assertEqual(len(list(self.supervisor.iterdir())), 1)

    def test_retained_corruption_is_not_overwritten(self):
        args = self.arguments()
        first = json.loads(self.run_task(args).stdout)
        path = Path(first["path"])
        path.write_text("corrupt fixture")
        self.assertEqual(self.run_task(args).returncode, 1)
        self.assertEqual(path.read_text(), "corrupt fixture")


if __name__ == "__main__":
    unittest.main()
