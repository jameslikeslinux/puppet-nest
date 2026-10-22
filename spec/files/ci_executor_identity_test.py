#!/usr/bin/env python3
"""Real local Git and fake Podman only; no registry, credentials or OS build."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "bin/ci-executor-receipt"
SHA = "a" * 40
REPO = "registry.example/nest/config/main"
FAKE = r'''#!/usr/bin/env python3
import json, os, sys
with open(os.environ['CALLS'], 'a') as stream:
    stream.write(json.dumps(sys.argv[1:]) + '\n')
if os.environ.get('FAIL_PODMAN'):
    print('private-secret-native-error', file=sys.stderr)
    sys.exit(37)
print(os.environ.get('LABEL_SHA' if sys.argv[1] == 'image' else 'OBSERVED_SHA', os.environ['CI_COMMIT_SHA']))
'''


class ExecutorIdentityTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.receipts = self.root / "receipts"
        self.receipts.mkdir()
        self.calls = self.root / "calls"
        podman = self.root / "podman"
        podman.write_text(FAKE)
        podman.chmod(0o755)
        self.env = dict(os.environ, CI_PROJECT_PATH="nest/config", CI_COMMIT_SHA=SHA, CI_PIPELINE_ID="123",
                        CI_REGISTRY_IMAGE="registry.example/nest/config", CI_COMMIT_REF_SLUG="main",
                        GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1",
                        CALLS=str(self.calls), PATH=str(self.root) + os.pathsep + os.environ["PATH"])

    def cli(self, *args, **changes):
        return subprocess.run([sys.executable, str(SCRIPT), *map(str, args)],
                              env=dict(self.env, **changes), text=True, capture_output=True, check=False)

    def member(self, cpu, index):
        ref = self.receipts / (cpu + ".ref")
        ref.write_text(REPO + "@sha256:" + format(index, "064x") + "\n")
        output = self.receipts / (cpu + ".json")
        return self.cli("record", ref, output, CPU=cpu, CI_JOB_ID=str(100 + index)), output

    def complete(self):
        for index, cpu in enumerate(("haswell", "cortex-a53", "sifive-u74"), start=1):
            result, _ = self.member(cpu, index)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_complete_pipeline_digest_members_and_bounded_source_checks(self):
        self.complete()
        result = self.cli("refs", self.receipts)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [REPO + "@sha256:" + format(i, "064x") for i in (1, 2, 3)])
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        self.assertEqual(len(calls), 6)
        for call in calls[::2]:
            for flag in ("--network=none", "--read-only", "--cap-drop=ALL", "--entrypoint=git"):
                self.assertIn(flag, call)
            self.assertEqual(call[-4:], ["-C", "/opt/nest", "rev-parse", "HEAD"])
            self.assertFalse(any("volume" in arg or arg.startswith("--env") for arg in call))

    def test_wrong_actual_source_or_podman_failure_never_writes_receipt(self):
        for changes in ({"OBSERVED_SHA": "b" * 40}, {"LABEL_SHA": "b" * 40}, {"FAIL_PODMAN": "1"}):
            ref = self.root / "image.ref"
            ref.write_text(REPO + "@sha256:" + "1" * 64 + "\n")
            output = self.root / "output.json"
            result = self.cli("record", ref, output, CPU="haswell", CI_JOB_ID="100", **changes)
            self.assertEqual(result.returncode, 1)
            self.assertFalse(output.exists())
            self.assertNotIn("private-secret", result.stderr)
            self.assertEqual(result.stdout, "")

    def test_record_never_replaces_an_existing_receipt(self):
        result, output = self.member("haswell", 1)
        self.assertEqual(result.returncode, 0)
        original = output.read_bytes()
        result, _ = self.member("haswell", 2)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(output.read_bytes(), original)

    def test_bad_reference_or_job_refuses_before_podman(self):
        ref = self.root / "image.ref"
        for value in (REPO + ":latest\n", REPO + "@sha256:" + "1" * 64 + "\nextra\n",
                      "other.example/nest/config/main@sha256:" + "1" * 64 + "\n"):
            ref.write_text(value)
            result = self.cli("record", ref, self.root / "output", CPU="haswell", CI_JOB_ID="100")
            self.assertEqual(result.returncode, 1)
            self.assertFalse(self.calls.exists())

    def test_missing_or_changed_member_never_emits_partial_set(self):
        self.complete()
        path = self.receipts / "cortex-a53.json"
        original = path.read_text()
        for key, value in (("sha", "b" * 40), ("pipeline", 122), ("cpu", "haswell"), ("job", True),
                           ("schema", True), ("project", "nest/stage0"), ("source_verification", "not_performed"),
                           ("job", 101), ("secret", "private-secret-value")):
            row = json.loads(original)
            row[key] = value
            path.write_text(json.dumps(row))
            result = self.cli("refs", self.receipts)
            self.assertEqual(result.returncode, 1, key)
            self.assertEqual(result.stdout, "")
            self.assertNotIn("private-secret", result.stderr)
        path.unlink()
        self.assertEqual(self.cli("refs", self.receipts).returncode, 1)

    def test_duplicate_keys_and_oversized_receipt_refuse(self):
        self.complete()
        path = self.receipts / "cortex-a53.json"
        for raw in ('{"schema":1,"schema":1}', " " * 4097):
            path.write_text(raw)
            result = self.cli("refs", self.receipts)
            self.assertEqual(result.returncode, 1)
            self.assertEqual(result.stdout, "")

    def test_containerfile_checks_out_exact_pipeline_commit_after_branch_moves(self):
        source = self.root / "source"
        source.mkdir()
        git = lambda *args: subprocess.check_output(["git", "-C", str(source), *args], env=self.env, text=True).strip()
        git("init", "-b", "main")
        git("config", "user.email", "fixture@example.invalid")
        git("config", "user.name", "Fixture")
        (source / "data").write_text("first")
        git("add", "data")
        git("commit", "-m", "First fixture")
        first = git("rev-parse", "HEAD")
        (source / "data").write_text("second")
        git("commit", "-am", "Moved branch fixture")
        command = next(line[4:] for line in (ROOT / "Containerfile").read_text().splitlines()
                       if line.startswith("RUN test "))
        destination = self.root / "clone"
        env = dict(self.env, SOURCE_SHA=first, REPOSITORY=str(source), SOURCE_URL=str(source), BRANCH="main",
                   BOLT_PROJECT=str(destination))
        result = subprocess.run(["sh", "-c", command], env=env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((destination / "data").read_text(), "first")
        self.assertEqual(subprocess.check_output(["git", "-C", str(destination), "rev-parse", "HEAD"], text=True).strip(), first)
        self.assertNotEqual(first, git("rev-parse", "HEAD"))
        # bin/build derives Stage 3's Puppet environment from the branch name.
        self.assertEqual(subprocess.check_output(["git", "-C", str(destination), "symbolic-ref", "HEAD"], text=True).strip(), "refs/heads/main")
        missing = self.root / "missing-commit"
        result = subprocess.run(["sh", "-c", command], env=dict(env, SOURCE_SHA="0" * 40, BOLT_PROJECT=str(missing)),
                                text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0, "An unavailable exact commit must never fall back to the branch")

    def test_containerfile_refuses_missing_malformed_and_absent_pins(self):
        command = next(line[4:] for line in (ROOT / "Containerfile").read_text().splitlines()
                       if line.startswith("RUN test "))
        for sha in ("", "main", "g" * 40, "a" * 39, "a" * 41):
            destination = self.root / "clone"
            result = subprocess.run(["sh", "-c", command], env=dict(self.env, SOURCE_SHA=sha, BOLT_PROJECT=str(destination)),
                                    capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(destination.exists())

    def test_ci_wires_exact_source_and_artifacts_not_mutable_index_members(self):
        ci = (ROOT / ".gitlab-ci.yml").read_text()
        self.assertIn('--build-arg=SOURCE_SHA="$CI_COMMIT_SHA"', ci)
        self.assertIn('executor-${CI_PIPELINE_ID}-${CI_JOB_ID}-${CPU}', ci)
        self.assertIn('paths: [\'executor-receipts/\']', ci)
        deploy = ci.split("'Deploy image':", 1)[1]
        self.assertIn("ci-executor-receipt refs", deploy)
        for cpu in ("haswell", "cortex-a53", "sifive-u74"):
            self.assertNotIn("${IMAGE}:" + cpu, deploy)


if __name__ == "__main__":
    unittest.main()
