#!/usr/bin/env python3
"""Release records are fixtures only: no real registry, builds, host or storage I/O."""

import copy
import importlib.util
import json

from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from concurrent.futures import ProcessPoolExecutor

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/nest-release-manifest.py"
SPEC = importlib.util.spec_from_file_location("nest_release_manifest", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)


def image(n):
    return "registry.example/nest/image@sha256:" + format(n, "064x")


def fixture():
    sources = {"nest/config": "a" * 40, "nest/overlay": "b" * 40, "nest/gentoo/portage": "c" * 40,
               "nest/gentoo/haskell": "d" * 40}
    expected = {"schema": 1, "kind": "nest_release_expectations", "release": "fixture-only",
                "sources": sources, "executor": {"source": sources["nest/config"], "image": image(1)},
                "members": [], "consumers": []}
    candidate = {"schema": 1, "kind": "nest_release_candidate", "release": "fixture-only", "outputs": []}
    for index, stage in enumerate(("stage0", "stage1", "stage2", "stage3", "tool"), start=1):
        project = "nest/" + stage if stage != "tool" else "nest/tools/bolt"
        sources[project] = format(index, "040x")
        member = {"id": stage, "stage": stage, "project": project, "cpu": "haswell", "variant": "server",
                  "platform": "wellsburg" if stage in ("stage2", "stage3") else None,
                  "host": "fixture-host" if stage == "stage3" else None, "mode": "fresh",
                  "bases": {"normal": image(2), "debug": image(3)} if stage in ("stage0", "stage1") else {"image": image(4)},
                  "compatibility": {"kernel": "fixture-kernel", "modules_abi": "fixture-abi", "firmware": "efi", "bootloader": "systemd-boot"}
                  if stage in ("stage2", "stage3") else {},
                  "identity_root": "/private/identities/fixture-host" if stage == "stage3" else None}
        artifacts = {"normal": image(10 + index), "debug": image(20 + index)} if stage in ("stage0", "stage1") else {"image": image(30 + index)}
        if stage == "stage3":
            artifacts = {"root": {"path": "/nest/releases/fixture-only/hosts/fixture-host", "dataset_guid": "123456789",
                                  "content_digest": "sha256:" + "d" * 64}}
        expected["members"].append(member)
        expected["consumers"].append({"project": project, "decision": "rebuild", "reason": "Fixture build only", "members": [stage]})
        candidate["outputs"].append({"member": copy.deepcopy(member), "executor": copy.deepcopy(expected["executor"]),
                                     "producer": {"project": project, "sha": sources[project], "pipeline": index, "job": 100 + index},
                                     "artifacts": artifacts})
    for name in release.TOOL_CONSUMERS:
        if not any(c["project"] == name for c in expected["consumers"]):
            expected["consumers"].append({"project": name, "decision": "defer", "reason": "Fixture excludes this consumer; no compatibility claim", "members": []})
    candidate["expectations_digest"] = release.digest(expected)
    return expected, candidate


def publish_fixture(arguments):
    directory, payload = arguments
    return release.retain(directory, payload)


class ReleaseManifestTest(unittest.TestCase):
    def setUp(self):
        self.expected, self.candidate = fixture()

    def validate(self):
        return release.validate(self.expected, self.candidate)

    def reseal(self):
        self.candidate["expectations_digest"] = release.digest(self.expected)

    def test_complete_record_and_canonical_digest(self):
        manifest = self.validate()
        self.assertEqual(len(manifest["candidate"]["outputs"]), 5)
        self.assertEqual(release.digest(manifest), release.digest(dict(reversed(list(manifest.items())))))

    def test_all_expected_members_required_not_aggregate_tags(self):
        self.candidate["outputs"].pop(1)
        with self.assertRaisesRegex(release.Invalid, "incomplete matrix"):
            self.validate()

    def test_duplicate_member_does_not_replace_missing_cpu(self):
        self.candidate["outputs"][1] = copy.deepcopy(self.candidate["outputs"][0])
        with self.assertRaisesRegex(release.Invalid, "duplicate member"):
            self.validate()

    def test_normal_debug_pair_required_and_distinct(self):
        for missing in (True, False):
            with self.subTest(missing=missing):
                self.expected, self.candidate = fixture()
                artifacts = self.candidate["outputs"][1]["artifacts"]
                if missing:
                    del artifacts["debug"]
                else:
                    artifacts["debug"] = artifacts["normal"]
                with self.assertRaises(release.Invalid):
                    self.validate()

    def test_mutable_tags_and_malformed_refs_rejected(self):
        for ref in ("registry.example/nest/image:latest", image(1) + "\n", image(1).replace("sha256", "sha512"),
                    "https://user:secret@example/image@sha256:" + "a" * 64, "repo@sha256:" + "a" * 64):
            with self.subTest(ref=ref):
                self.expected, self.candidate = fixture()
                self.candidate["outputs"][0]["artifacts"]["normal"] = ref
                with self.assertRaises(release.Invalid):
                    self.validate()

    def test_changed_frozen_source_or_base_invalidates_digest(self):
        for target, key, value in ((self.expected["sources"], "nest/overlay", "e" * 40),):
            target[key] = value
        with self.assertRaisesRegex(release.Invalid, "changed inputs/matrix"):
            self.validate()
        self.expected, self.candidate = fixture()
        self.expected["members"][1]["bases"]["debug"] = image(999)
        with self.assertRaisesRegex(release.Invalid, "changed inputs/matrix"):
            self.validate()

    def test_stale_executor_both_expected_and_actual(self):
        self.expected["executor"]["source"] = "e" * 40
        with self.assertRaisesRegex(release.Invalid, "stale config"):
            self.validate()
        self.expected, self.candidate = fixture()
        self.candidate["outputs"][2]["executor"]["image"] = image(999)
        with self.assertRaisesRegex(release.Invalid, "stale executor"):
            self.validate()

    def test_haskell_is_required_and_changes_invalidate_the_frozen_selection(self):
        del self.expected["sources"]["nest/gentoo/haskell"]
        self.reseal()
        with self.assertRaisesRegex(release.Invalid, "missing.*Haskell"):
            self.validate()
        self.expected, self.candidate = fixture()
        self.expected["sources"]["nest/gentoo/haskell"] = "e" * 40
        with self.assertRaisesRegex(release.Invalid, "changed inputs/matrix"):
            self.validate()

    def test_producer_source_project_and_numeric_ids(self):
        for key, value in (("project", "nest/stage1"), ("sha", "f" * 40), ("pipeline", 0), ("job", True)):
            with self.subTest(key=key):
                self.expected, self.candidate = fixture()
                self.candidate["outputs"][0]["producer"][key] = value
                with self.assertRaises(release.Invalid):
                    self.validate()

    def test_compatibility_cpu_variant_and_mode_must_match(self):
        for key, value in (("compatibility", {"firmware": "wrong-family"}), ("cpu", "sifive-u74"),
                           ("variant", "mobile"), ("mode", "refresh")):
            with self.subTest(key=key):
                self.expected, self.candidate = fixture()
                self.candidate["outputs"][3]["member"][key] = value
                with self.assertRaisesRegex(release.Invalid, "compatibility mismatch"):
                    self.validate()

    def test_stage3_generation_not_mutable_host_identity_source(self):
        self.candidate["outputs"][3]["artifacts"]["root"]["path"] = "/nest/hosts/fixture-host"
        with self.assertRaisesRegex(release.Invalid, "versioned host generation"):
            self.validate()
        self.expected, self.candidate = fixture()
        self.expected["members"][3]["identity_root"] = "/nest/releases/fixture-only"
        self.reseal()
        with self.assertRaisesRegex(release.Invalid, "overlap"):
            self.validate()

    def test_deferred_consumers_not_implicitly_rebuilt(self):
        self.expected["consumers"][0]["decision"] = "defer"
        self.reseal()
        with self.assertRaisesRegex(release.Invalid, "reuse/rebuild"):
            self.validate()

    def test_unclassified_known_consumers_and_missing_producers_fail(self):
        for project in ("nest/tools/whisper.cpp", "nest/tools/bolt"):
            with self.subTest(project=project):
                self.expected, self.candidate = fixture()
                self.expected["consumers"] = [c for c in self.expected["consumers"] if c["project"] != project]
                self.reseal()
                with self.assertRaisesRegex(release.Invalid, "unclassified"):
                    self.validate()

    def test_reuse_requires_exact_member_receipt(self):
        self.expected["consumers"][0]["decision"] = "reuse"
        self.reseal()
        self.validate()
        self.expected["consumers"][0]["members"] = []
        self.reseal()
        with self.assertRaises(release.Invalid):
            self.validate()

    def test_duplicate_selection_and_unknown_fields_fail(self):
        self.expected["members"].append(dict(self.expected["members"][0], id="another"))
        self.reseal()
        with self.assertRaisesRegex(release.Invalid, "duplicate selection"):
            self.validate()
        self.expected, self.candidate = fixture()
        self.candidate["outputs"][0]["secret"] = "never copy this"
        with self.assertRaisesRegex(release.Invalid, "unexpected"):
            self.validate()

    def test_duplicate_host_path_rejected_across_variants(self):
        self.expected["members"].append(dict(self.expected["members"][3], id="other-variant", variant="workstation"))
        self.reseal()
        with self.assertRaisesRegex(release.Invalid, "duplicate host"):
            self.validate()

    def test_same_digest_in_different_repositories_is_not_a_debug_pair(self):
        artifacts = self.candidate["outputs"][0]["artifacts"]
        artifacts["debug"] = artifacts["normal"].replace("/image@", "/debug@")
        with self.assertRaisesRegex(release.Invalid, "distinct"):
            self.validate()

    def test_json_duplicate_keys_nonfinite_and_oversize(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "bad.json"
            for raw in ('{"schema":1,"schema":2}', '{"schema":NaN}', "[", "9" * 5000, " " * (release.LIMIT + 1)):
                path.write_text(raw)
                with self.assertRaises(release.Invalid):
                    release.load(path)

    def test_retention_concurrent_idempotent_and_reopened_after_input_removed(self):
        payload = release.canonical(self.validate())
        with tempfile.TemporaryDirectory() as directory:
            with ProcessPoolExecutor(max_workers=3) as pool:
                paths = list(pool.map(publish_fixture, [(directory, payload)] * 6))
            self.assertEqual(len(set(paths)), 1)
            retained = Path(paths[0])
            self.assertEqual(retained.read_bytes(), payload)
            self.assertEqual(retained.stat().st_mode & 0o777, 0o644)
            self.assertEqual(len(list(Path(directory).iterdir())), 1)
            retained.write_text("conflict")
            with self.assertRaisesRegex(release.Invalid, "conflicts"):
                release.retain(directory, payload)
            self.assertEqual(retained.read_text(), "conflict")

    def test_retention_refuses_symlink_and_missing_directory(self):
        payload = release.canonical(self.validate())
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(release.Invalid):
                release.retain(str(Path(directory) / "missing"), payload)
            target = Path(release.retain(directory, payload))
            target.unlink()
            other = Path(directory) / "other"
            other.write_bytes(payload)
            target.symlink_to(other)
            with self.assertRaisesRegex(release.Invalid, "regular file"):
                release.retain(directory, payload)

    def test_real_cli_read_only_then_retains_exact_manifest(self):
        with tempfile.TemporaryDirectory() as directory:
            expected = Path(directory) / "expectations.json"
            candidate = Path(directory) / "candidate.json"
            expected.write_bytes(release.canonical(self.expected))
            candidate.write_bytes(release.canonical(self.candidate))
            cmd = [sys.executable, str(SCRIPT), "--expectations", str(expected), "--candidate", str(candidate)]
            before = set(Path(directory).iterdir())
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            receipt = json.loads(result.stdout)
            self.assertIsNone(receipt["path"])
            self.assertFalse(receipt["promotion_authorized"])
            self.assertEqual(receipt["resource_verification"], "not_performed")
            self.assertEqual(set(Path(directory).iterdir()), before)
            result = subprocess.run(cmd + ["--output-dir", directory], capture_output=True, text=True, check=True)
            receipt = json.loads(result.stdout)
            expected.unlink()
            candidate.unlink()
            retained = json.loads(Path(receipt["path"]).read_bytes())
            self.assertEqual(release.digest(retained), receipt["manifest_digest"])
            self.assertTrue(receipt["readback_verified"])

    def test_cli_does_not_echo_untrusted_secret_or_traceback(self):
        with tempfile.TemporaryDirectory() as directory:
            expected = Path(directory) / "expectations.json"
            candidate = Path(directory) / "candidate.json"
            self.candidate["outputs"][0]["producer"]["job"] = "private-secret-value"
            expected.write_bytes(release.canonical(self.expected))
            candidate.write_bytes(release.canonical(self.candidate))
            result = subprocess.run([sys.executable, str(SCRIPT), "--expectations", str(expected),
                                     "--candidate", str(candidate)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            self.assertNotIn("private-secret-value", result.stderr)
            self.assertNotIn("Traceback", result.stderr)
            self.assertEqual(result.stdout, "")


if __name__ == "__main__":
    unittest.main()
