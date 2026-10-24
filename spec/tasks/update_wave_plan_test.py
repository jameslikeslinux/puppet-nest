#!/usr/bin/env python3
"""Offline exact-policy planning and refusal tests; no host access."""

import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
TASK = ROOT / "tasks/update_wave_plan.py"
SPEC = importlib.util.spec_from_file_location("wave_plan", TASK)
assert SPEC is not None and SPEC.loader is not None
W = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(W)


def policy():
    # Deliberately fictitious topology, not a production release or host policy.
    domains = ["core", "usb-parent", "joined", "independent-a", "independent-b"]
    hosts = [("canary", ["independent-a"]), ("core-a", ["core", "usb-parent"]),
             ("core-b", ["core"]), ("usb-child", ["usb-parent"]),
             ("joined-a", ["joined"]), ("joined-b", ["joined"]),
             ("leaf", ["independent-b"])]
    return {"schema": 1, "kind": "nest_update_wave_policy", "release": "sha256:" + "b" * 64,
            "config_source": "a" * 40, "max_parallel": 3, "domains": domains,
            "hosts": [{"name": name, "platform": "fixture-platform", "kernel": "6.18.56-fixture",
                       "domains": membership} for name, membership in hosts],
            "excluded": ["fixture-console"], "canaries": ["canary"]}


class WavePlanTest(unittest.TestCase):
    def setUp(self):
        self.policy = policy()
        self.targets = [row["name"] for row in self.policy["hosts"]]

    def run_plan(self):
        return W.plan(self.policy, self.targets)

    def test_serial_domains_and_bounded_independent_parallelism(self):
        result = self.run_plan()
        self.assertEqual(result["waves"], [["canary"], ["core-a", "joined-a", "leaf"],
                                           ["core-b", "usb-child", "joined-b"]])
        seen = []
        indexed = {row["name"]: row for row in self.policy["hosts"]}
        for wave in result["waves"]:
            self.assertLessEqual(len(wave), 3)
            domains = [d for name in wave for d in indexed[name]["domains"]]
            self.assertEqual(len(domains), len(set(domains)))
            seen.extend(wave)
        self.assertEqual(set(seen), set(self.targets))
        self.assertEqual(len(seen), len(self.targets))
        self.assertEqual(result["host_count"], len(self.targets))
        for key in ("topology_verified", "release_binding_verified", "preparation_observed",
                    "execution_authorized", "acceptance_recorded"):
            self.assertIs(result[key], False)
        self.assertEqual(result["reboot_eligible"], [])

    def test_inventory_order_does_not_reorder_policy(self):
        first = self.run_plan()
        self.targets.reverse()
        self.assertEqual(self.run_plan(), first)

    def test_multiple_canaries_are_isolated_first_in_policy_order(self):
        self.policy["canaries"] = self.targets[:2]
        self.assertEqual(self.run_plan()["waves"][:2], [["canary"], ["core-a"]])

    def test_global_serial_mode(self):
        self.policy["max_parallel"] = 1
        self.assertEqual(self.run_plan()["waves"], [[name] for name in self.targets])

    def test_partial_extra_duplicate_or_unknown_inventory_refuses(self):
        for targets in (self.targets[:-1], self.targets + ["unknown"], self.targets + [self.targets[0]], []):
            with self.subTest(targets=targets), self.assertRaises(ValueError):
                W.plan(self.policy, targets)

    def test_no_canary_or_unordered_canary_refuses(self):
        for value in ([], ["missing"], [self.targets[-1]], ["canary", "canary"]):
            self.policy["canaries"] = value
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.run_plan()

    def test_exclusion_refuses_even_when_explicitly_selected(self):
        self.policy["excluded"].append("core-a")
        with self.assertRaises(ValueError):
            self.run_plan()

    def test_recovery_console_floor_cannot_be_omitted_or_overridden(self):
        for name in ("fixture-console", "other-console.nest"):
            p = policy()
            p["hosts"][0]["name"] = name
            p["canaries"] = [name]
            p["excluded"] = []
            with self.subTest(name=name), self.assertRaises(ValueError):
                W.plan(p, [row["name"] for row in p["hosts"]])

    def test_missing_unknown_duplicate_and_unused_domains_refuse(self):
        for membership in ([], ["unknown"], ["core", "core"]):
            p = policy()
            p["hosts"][1]["domains"] = membership
            with self.subTest(membership=membership), self.assertRaises(ValueError):
                W.plan(p, self.targets)
        self.policy["domains"].append("unassigned")
        with self.assertRaises(ValueError):
            self.run_plan()

    def test_duplicate_host_and_malformed_kernel_or_platform_refuse(self):
        for field, value in (("name", "canary"), ("platform", "bad platform"), ("kernel", "x; reboot")):
            p = policy()
            p["hosts"][1][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                W.plan(p, self.targets)

    def test_strict_schema_limits_and_unknown_fields(self):
        for key, value in (("schema", True), ("schema", 2), ("max_parallel", True),
                           ("max_parallel", 0), ("max_parallel", 5), ("max_parallel", 2.0),
                           ("release", "sha256:" + "b" * 63), ("config_source", "main"),
                           ("kind", "other"), ("unknown", "private log")):
            p = policy()
            p[key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                W.plan(p, self.targets)
        self.policy["hosts"][0]["unknown"] = "private log"
        with self.assertRaises(ValueError):
            self.run_plan()

    def test_policy_digest_binds_kernel_scope_and_declared_topology(self):
        first = self.run_plan()["policy_sha256"]
        self.policy["hosts"][0]["kernel"] = "6.18.57-qualified-fixture"
        self.assertNotEqual(self.run_plan()["policy_sha256"], first)
        self.assertEqual(len(first), 64)

    def task(self, raw):
        return subprocess.run([sys.executable, str(TASK)], input=raw, capture_output=True, check=False)

    def test_actual_stdin_task_and_bolt_noop_metadata(self):
        params = {"policy": self.policy, "targets": self.targets, "_noop": True}
        result = self.task(json.dumps(params).encode())
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), self.run_plan())
        self.assertEqual(result.stderr, b"")

    def test_actual_task_refuses_duplicate_keys_and_oversized_or_malformed_input(self):
        for raw in (b'{"policy":{},"policy":{},"targets":[]}', b"x" * (W.LIMIT + 1),
                    b"not JSON", b"[]", b"null", b"\xff", b'{"targets":[{}],"policy":{}}'):
            result = self.task(raw)
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertEqual(json.loads(result.stdout)["_error"]["kind"], "nest/update-wave-policy")
            self.assertEqual(result.stderr, b"")

    def test_task_never_returns_arbitrary_private_input(self):
        params = {"policy": self.policy, "targets": self.targets, "private": "SECRET LOG"}
        result = self.task(json.dumps(params).encode())
        self.assertEqual(result.returncode, 1)
        self.assertNotIn(b"SECRET LOG", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
