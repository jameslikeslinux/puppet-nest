"""Network collector tests use isolated native-output fixtures, not live endpoints."""

import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
TASK = Path(__file__).resolve().parents[2] / "tasks/update_network_health.py"
spec = importlib.util.spec_from_file_location("update_network_health", TASK)
assert spec is not None and spec.loader is not None
health = importlib.util.module_from_spec(spec)
spec.loader.exec_module(health)
BOOT = "11111111-2222-3333-4444-555555555555"
ENDPOINT = {"hostname": "service.example", "addresses": ["192.0.2.1"], "path": "/readyz", "status": 200}


class Fixture:
    def __init__(self):
        self.calls = []
        self.resolution = "192.0.2.1 STREAM service.example\n192.0.2.1 DGRAM\n192.0.2.1 RAW\n"
        self.route = [{"dst": "192.0.2.1", "dev": "eth0", "prefsrc": "192.0.2.2", "gateway": "192.0.2.254"}]
        self.https = "200 192.0.2.1 0"

    def __call__(self, argv):
        self.calls.append(argv)
        if argv[:2] == ["getent", "ahosts"]:
            return self.resolution
        if argv[:4] == ["ip", "-json", "route", "get"]:
            return json.dumps(self.route)
        if argv[:2] == ["curl", "-q"]:
            return self.https
        raise AssertionError("Unexpected command")


class NetworkHealthTest(unittest.TestCase):
    def collect(self, run=None, endpoints=None, boot=None, hostname=None):
        return health.collect([ENDPOINT] if endpoints is None else endpoints, run or Fixture(),
                              boot or (lambda: BOOT), hostname or (lambda: "fixture-host"))

    def test_exact_client_route_resolution_and_system_trust_without_acceptance(self):
        run = Fixture()
        result = self.collect(run)
        self.assertEqual(result["result"], "pass")
        self.assertFalse(result["acceptance_recorded"])
        self.assertEqual(result["hostname"], "fixture-host")
        self.assertEqual(result["boot_id"], BOOT)
        self.assertEqual(result["endpoints"][0]["routes"][0]["gateway"], "192.0.2.254")
        self.assertEqual(len(run.calls), 5)
        curl = run.calls[2]
        self.assertEqual(curl[:2], ["curl", "-q"])
        self.assertIn("--noproxy", curl)
        self.assertIn("--proto", curl)
        self.assertEqual(curl[-1], "https://service.example/readyz")
        self.assertNotIn("--insecure", curl)
        self.assertNotIn("--location", curl)

    def test_status_mismatch_retains_available_observation_as_failed(self):
        run = Fixture()
        run.https = "503 192.0.2.1 0"
        row = self.collect(run)["endpoints"][0]
        self.assertEqual(row["availability"], "available")
        self.assertEqual(row["result"], "fail")
        self.assertEqual(row["https"]["status"], 503)

    def test_unavailable_is_not_empty_healthy_resolution(self):
        for resolution in ("", "invalid", "127.0.0.1 STREAM service.example", "192.0.2.9 STREAM service.example"):
            run = Fixture()
            run.resolution = resolution
            self.assertEqual(self.collect(run)["result"], "fail")
            self.assertEqual(len(run.calls), 1)

    def test_extra_or_missing_resolution_addresses_refuse_before_http(self):
        run = Fixture()
        run.resolution += "192.0.2.3 STREAM service.example\n"
        self.assertEqual(self.collect(run)["endpoints"][0]["reason"], "resolution_policy_mismatch")
        self.assertEqual(len(run.calls), 1)

    def test_malformed_local_blackhole_or_missing_source_route_refuses(self):
        for route in ([], [{"type": "blackhole"}], [dict(Fixture().route[0], dev="lo")],
                      [dict(Fixture().route[0], dst="192.0.2.9")], [{"dst": "192.0.2.1", "dev": "eth0"}],
                      [dict(Fixture().route[0], dev="bad\ninterface")]):
            run = Fixture()
            run.route = route
            self.assertEqual(self.collect(run)["result"], "fail")
            self.assertNotIn("curl", [call[0] for call in run.calls])

    def test_wrong_remote_unverified_trust_and_malformed_status_refuse(self):
        for https in ("200 192.0.2.9 0", "200 192.0.2.1 60", "200 192.0.2.1", "bad 192.0.2.1 0"):
            run = Fixture()
            run.https = https
            self.assertEqual(self.collect(run)["result"], "fail")

    def test_resolution_or_route_race_refuses(self):
        for changed_command in ("getent", "ip"):
            run = Fixture()
            counts = {}

            def changing(argv):
                counts[argv[0]] = counts.get(argv[0], 0) + 1
                raw = run(argv)
                if argv[0] == changed_command and counts[argv[0]] == 2:
                    return raw.replace("192.0.2.1", "192.0.2.3") if changed_command == "getent" else raw.replace("eth0", "eth1")
                return raw

            self.assertEqual(self.collect(changing)["endpoints"][0]["reason"], "network_changed_during_collection")

    def test_boot_or_hostname_change_refuses_whole_bundle(self):
        for kwargs in ({"boot": iter([BOOT, "aaaaaaaa-2222-3333-4444-555555555555"]).__next__},
                       {"hostname": iter(["fixture-host", "other-host"]).__next__}):
            with self.assertRaisesRegex(health.Unavailable, "host_changed"):
                self.collect(**kwargs)

    def test_invalid_policy_refuses_before_commands(self):
        invalid = [[], [ENDPOINT] * 5, [ENDPOINT, ENDPOINT]]
        for key, values in (("hostname", ["localhost", "192.0.2.1", "UPPER.example", "service.example:443", "$(id).example"]),
                            ("path", ["//bad?secret", "/../secret", "/?token=private", "/#fragment"]),
                            ("addresses", [[], ["192.0.2.1"] * 2, ["::1"], ["0.0.0.0"], ["fe80::1"], ["224.0.0.1"], [12]]),
                            ("status", [True, 199, 300, "200"])):
            invalid.extend([[dict(ENDPOINT, **{key: value})] for value in values])
        invalid.extend([[dict(ENDPOINT, extra="private")], [dict(ENDPOINT, addresses="192.0.2.1")]])
        for endpoints in invalid:
            run = Fixture()
            with self.subTest(endpoints=endpoints), self.assertRaises(health.Unavailable):
                self.collect(run, endpoints)
            self.assertEqual(run.calls, [])

    def test_ipv6_and_direct_route_are_not_relabelled_ipv4(self):
        run = Fixture()
        run.resolution = "2001:db8::1 STREAM service.example\n"
        run.route = [{"dst": "2001:db8::1", "dev": "eth0", "src": "2001:db8::2"}]
        run.https = "204 2001:db8::1 0"
        endpoint = dict(ENDPOINT, addresses=["2001:db8::1"], status=204)
        self.assertEqual(self.collect(run, [endpoint])["result"], "pass")

    def test_one_endpoint_failure_does_not_erase_other_observation(self):
        run = Fixture()

        def unavailable(argv):
            if argv[-1] == "broken.example":
                raise health.Unavailable("command_failed")
            return run(argv)

        result = self.collect(unavailable, [ENDPOINT, dict(ENDPOINT, hostname="broken.example")])
        self.assertEqual([row["result"] for row in result["endpoints"]], ["pass", "fail"])
        self.assertEqual(result["result"], "fail")

    def test_command_timeout_failure_deadline_and_fixed_environment(self):
        for failure in (OSError("private"), subprocess.TimeoutExpired("private", 1)):
            with patch.object(health.subprocess, "run", side_effect=failure):
                with self.assertRaisesRegex(health.Unavailable, "command_unavailable"):
                    health.Commands()(["getent", "ahosts", "service.example"])
        with patch.object(health.subprocess, "run", return_value=subprocess.CompletedProcess([], 60, b"private", b"private")):
            with self.assertRaisesRegex(health.Unavailable, "command_failed"):
                health.Commands()(["curl"])
        runner = health.Commands()
        runner.deadline = 0
        with self.assertRaisesRegex(health.Unavailable, "collection_deadline"):
            runner(["curl"])
        with patch.object(health.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, b"ok", b"")) as command:
            self.assertEqual(health.Commands()(["curl"]), "ok")
            self.assertEqual(command.call_args.kwargs["env"], health.ENV)
            self.assertNotIn("HTTPS_PROXY", command.call_args.kwargs["env"])
            self.assertLessEqual(command.call_args.kwargs["timeout"], 6)

    def test_command_output_and_encoding_are_bounded(self):
        for raw, reason in ((b"x" * 65537, "command_output_limit"), (b"\xff", "command_encoding")):
            with patch.object(health.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, raw, b"")):
                with self.assertRaisesRegex(health.Unavailable, reason):
                    health.Commands()(["getent"])

    def test_real_stdin_entrypoint_rejects_bad_input_without_private_echo(self):
        for payload in ({"endpoints": [dict(ENDPOINT, path="/private?credential=secret")]}, {}, [], {"endpoints": []}):
            completed = subprocess.run([sys.executable, str(TASK)], input=json.dumps(payload), capture_output=True, text=True, check=False)
            self.assertEqual(completed.returncode, 1)
            self.assertIn("_error", json.loads(completed.stdout))
            self.assertNotIn("private", completed.stdout)
            self.assertEqual(completed.stderr, "")


if __name__ == "__main__":
    unittest.main()
