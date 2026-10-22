#!/usr/bin/env python3
"""Real local Git/input hashing and fake Bolt/Podman; never build an OS image."""

import copy
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = runpy.run_path(str(ROOT / "scripts/nest-release-manifest.py"))
INPUTS = runpy.run_path(str(ROOT / "scripts/nest-executor-inputs.py"))
FAKE_BOLT = r'''#!/usr/bin/env python3
import json, os, pathlib, sys
p = json.load(sys.stdin)
with open(os.environ['CALLS'], 'a') as stream:
    stream.write(json.dumps({'args': sys.argv[1:], 'params': p}) + '\n')
if os.environ.get('FAIL_BUILD'):
    print('private-secret-error', file=sys.stderr)
    sys.exit(37)
if os.environ.get('CHANGE_MODULE'):
    (pathlib.Path(os.environ['EXECUTOR']) / '.modules/stdlib/data').write_text('changed')
stage = sys.argv[3].split('::')[-1]
repo = os.environ['CI_REGISTRY_IMAGE'] + ('/' + p['variant'] if stage != 'stage0' else '')
row = ({'normal': repo + '@sha256:' + 'c' * 64, 'debug': repo + '/debug@sha256:' + 'd' * 64}
       if stage != 'stage2' else {'image': repo + '@sha256:' + 'c' * 64})
if os.environ.get('BAD_OUTPUT') == 'partial':
    row.pop(next(iter(row)))
if os.environ.get('BAD_OUTPUT') == 'mutable':
    row[next(iter(row))] = repo + ':latest'
if os.environ.get('BAD_OUTPUT') == 'same':
    row['debug'] = repo + '/debug@sha256:' + 'c' * 64
if os.environ.get('BAD_OUTPUT') == 'wrong_repo':
    row[next(iter(row))] = 'other.example/nest/stage0@sha256:' + 'c' * 64
print(json.dumps(row))
'''


class CandidateBuildTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.project = self.root / "executor"
        self.project.mkdir()
        self.env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1", PYTHONDONTWRITEBYTECODE="1")
        self.env.update(CI_PIPELINE_ID="901", CI_JOB_ID="902", CI_REGISTRY="registry.example",
                        CI_PROJECT_DIR=str(self.root / "producer"), CALLS=str(self.root / "calls"), EXECUTOR=str(self.project))
        for name in ("bin/ci-release-build", "bin/ci-executor-receipt", "bin/bolt-wrapper",
                     "scripts/nest-release-manifest.py", "scripts/nest-executor-inputs.py"):
            path = self.project / name
            path.parent.mkdir(exist_ok=True)
            shutil.copy2(ROOT / name, path)
        (self.project / "Puppetfile").write_text("fixture only\n")
        self.sha = self.init_git(self.project)
        modules = self.project / ".modules"
        modules.mkdir()
        subprocess.run(["git", "clone", "--quiet", str(self.project), str(modules / "nest")], env=self.env, check=True)
        for name in ("stdlib", "private", "reboot", "ruby_task_helper", "kubecm"):
            (modules / name).mkdir()
            (modules / name / "data").write_text("fixture only")
        base = "registry.example/nest/tools/bolt@sha256:" + "f" * 64
        observed = INPUTS["observe"](self.project, self.sha, base)
        (self.project / ".executor-inputs.json").write_bytes(INPUTS["canonical"](observed))
        self.receipt = {"schema": 2, "kind": "nest_config_executor_member", "project": "nest/config", "sha": self.sha,
                        "pipeline": 801, "job": 802, "cpu": "haswell", "image": "registry.example/nest/config/main@sha256:" + "e" * 64,
                        "source_verification": "git_head_and_oci_revision", "inputs": observed}
        producer = self.root / "producer"
        producer.mkdir()
        (producer / "gitlab-ci.yml").write_text("fixture only")
        self.producer_sha = self.init_git(producer)
        tools = MANIFEST["TOOL_CONSUMERS"]
        self.expected = {"schema": 1, "kind": "nest_release_expectations", "release": "fixture-only",
                         "sources": {"nest/config": self.sha, "nest/overlay": "a" * 40,
                                     "nest/gentoo/portage": "b" * 40, "nest/gentoo/haskell": "c" * 40},
                         "executor": {"source": self.sha, "image": self.receipt["image"]}, "members": [],
                         "consumers": [{"project": p, "decision": "defer", "reason": "Fixture only", "members": []} for p in sorted(tools)]}
        fake = self.root / "fake"
        fake.mkdir()
        for name, source in (("bolt", FAKE_BOLT), ("podman", "#!/bin/sh\nexit 0\n")):
            path = fake / name
            path.write_text(source)
            path.chmod(0o755)
        self.env["PATH"] = str(fake) + os.pathsep + self.env["PATH"]
        self.env["ZDOTDIR"] = str(fake)
        self.output = self.root / "output"
        self.output.mkdir()
        self.select("stage1")

    def init_git(self, path):
        def git(*args):
            return subprocess.check_output(["git", "-C", str(path), *args], env=self.env, stderr=subprocess.DEVNULL, text=True).strip()
        git("init", "-b", "main")
        git("config", "user.email", "fixture@example.invalid")
        git("config", "user.name", "Fixture")
        git("add", ".")
        git("commit", "-m", "Fixture only")
        return git("rev-parse", "HEAD")

    def select(self, stage, mode="fresh"):
        project = "nest/" + stage
        member = {"id": "fixture-member", "stage": stage, "project": project, "cpu": "haswell", "variant": "server",
                  "platform": "vanilla" if stage == "stage2" else None, "host": None, "mode": mode,
                  "bases": {key: "registry.example/nest/base@sha256:" + digit * 64
                            for key, digit in (("normal", "1"), ("debug", "2"))} if stage == "stage1"
                  else {"image": "registry.example/nest/base@sha256:" + "1" * 64},
                  "compatibility": {key: "fixture only" for key in ("kernel", "modules_abi", "firmware", "bootloader")}
                  if stage == "stage2" else {}, "identity_root": None}
        self.expected["members"] = [member]
        self.expected["sources"][project] = self.producer_sha
        self.expected["consumers"] = [r for r in self.expected["consumers"] if r["project"] not in ("nest/stage0", "nest/stage1", "nest/stage2")]
        self.expected["consumers"].append({"project": project, "decision": "rebuild", "reason": "Fixture only", "members": [member["id"]]})
        self.env.update(CI_PROJECT_PATH=project, CI_COMMIT_SHA=self.producer_sha,
                        CI_JOB_IMAGE=self.receipt["image"], CI_REGISTRY_IMAGE="registry.example/" + project)

    def cli(self, **env):
        expected = self.root / "expectations.json"
        receipt = self.root / "receipt.json"
        expected.write_text(json.dumps(self.expected))
        receipt.write_text(json.dumps(self.receipt))
        return subprocess.run([sys.executable, str(self.project / "bin/ci-release-build"), "--expectations", str(expected),
                               "--executor-receipt", str(receipt), "--member", "fixture-member", "--output-dir", str(self.output)],
                              env=dict(self.env, **env), text=True, capture_output=True)

    def calls(self):
        path = self.root / "calls"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def test_stage0_stage1_stage2_execute_frozen_candidates_and_reopen_result(self):
        for stage in ("stage0", "stage1", "stage2"):
            self.select(stage, "refresh" if stage == "stage0" else "fresh")
            self.output = self.root / stage
            self.output.mkdir()
            result = self.cli()
            self.assertEqual(result.returncode, 0, result.stderr)
            row = json.loads((self.output / "fixture-member.json").read_text())
            self.assertEqual(row["expectations_digest"], MANIFEST["digest"](self.expected))
            self.assertEqual(row["executor_receipt"], self.receipt)
            self.assertEqual(row["output"]["member"], self.expected["members"][0])
            self.assertEqual(row["output"]["producer"]["job"], 902)
            candidate = {"schema": 1, "kind": "nest_release_candidate", "release": self.expected["release"],
                         "expectations_digest": row["expectations_digest"], "outputs": [row["output"]]}
            self.assertEqual(MANIFEST["validate"](self.expected, candidate)["candidate"], candidate)
            self.assertTrue(json.loads(result.stdout)["readback_verified"])
            call = self.calls()[-1]
            self.assertEqual(call["args"], ["plan", "run", "nest::build::" + stage, "--project", str(self.project), "--params", "-", "--format", "json"])
            params = call["params"]
            self.assertEqual(params["repo_revisions"], {"gentoo": "b" * 40, "nest": "a" * 40, "haskell": "c" * 40})
            self.assertEqual(params["candidate"], "p901-j902")
            self.assertTrue(params["build"] and params["deploy"] and params["init"])
            self.assertIsNone(params["registry_username"])
            self.assertNotIn("password", json.dumps(params))

    def test_job_or_image_identity_mismatch_stops_before_bolt(self):
        for env in ({"CI_COMMIT_SHA": "d" * 40}, {"CI_JOB_IMAGE": "registry.example/nest/config:latest"},
                    {"CI_PROJECT_PATH": "nest/stage2"}, {"CI_JOB_ID": "0"}, {"CI_PIPELINE_ID": "true"},
                    {"CI_REGISTRY_IMAGE": "other.example/nest/stage1"}):
            self.assertEqual(self.cli(**env).returncode, 1)
            self.assertEqual(self.calls(), [])

    def test_changed_actual_module_stops_before_bolt(self):
        (self.project / ".modules/stdlib/data").write_text("changed")
        self.assertEqual(self.cli().returncode, 1)
        self.assertEqual(self.calls(), [])

    def test_changed_producer_checkout_stops_before_bolt(self):
        (self.root / "producer/gitlab-ci.yml").write_text("changed")
        self.assertEqual(self.cli().returncode, 1)
        self.assertEqual(self.calls(), [])

    def test_old_or_malformed_executor_receipt_stops_before_bolt(self):
        original = copy.deepcopy(self.receipt)
        for key, value in (("schema", 1), ("pipeline", True), ("sha", "d" * 40), ("image", 123),
                           ("image", "registry.example/nest/config:latest")):
            self.receipt = copy.deepcopy(original)
            self.receipt[key] = value
            self.assertEqual(self.cli().returncode, 1)
            self.assertEqual(self.calls(), [])

    def test_stage0_fresh_and_reuse_decision_refuse(self):
        self.select("stage0", "fresh")
        self.assertEqual(self.cli().returncode, 1)
        self.select("stage1")
        self.expected["consumers"][-1]["decision"] = "reuse"
        self.assertEqual(self.cli().returncode, 1)
        self.assertEqual(self.calls(), [])

    def test_failed_build_never_returns_or_replays_success(self):
        result = self.cli(FAIL_BUILD="1")
        self.assertEqual(result.returncode, 1)
        self.assertNotIn("private-secret", result.stderr)
        self.assertEqual(result.stdout, "")
        self.assertFalse((self.output / "fixture-member.json").exists())
        self.assertEqual(self.cli().returncode, 1)
        self.assertEqual(len(self.calls()), 1)

    def test_partial_mutable_wrong_repo_or_identical_outputs_refuse(self):
        for bad in ("partial", "mutable", "same", "wrong_repo"):
            self.output = self.root / bad
            self.output.mkdir()
            result = self.cli(BAD_OUTPUT=bad)
            self.assertEqual(result.returncode, 1, bad)
            self.assertFalse((self.output / "fixture-member.json").exists())

    def test_build_cannot_change_its_executor_and_emit_success(self):
        self.assertEqual(self.cli(CHANGE_MODULE="1").returncode, 1)
        self.assertFalse((self.output / "fixture-member.json").exists())

    def test_success_never_overwrites_or_runs_again(self):
        self.assertEqual(self.cli().returncode, 0)
        target = self.output / "fixture-member.json"
        original = target.read_bytes()
        self.assertEqual(self.cli().returncode, 1)
        self.assertEqual(target.read_bytes(), original)
        self.assertEqual(len(self.calls()), 1)


if __name__ == "__main__":
    unittest.main()
