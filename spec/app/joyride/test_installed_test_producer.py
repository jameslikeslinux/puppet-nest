"""Synthetic producer security/integration contracts; no real keys or cluster I/O."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[3]
SPEC = importlib.util.spec_from_file_location("installed_test_producer", ROOT / "files/app/joyride/installed_test_producer.py")
assert SPEC is not None and SPEC.loader is not None
producer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(producer)
DIGEST = "sha256:" + "a" * 64
HEAD = "b" * 40
IDENTITY = {"deployment_uid": "10000000-0000-4000-8000-000000000001", "generation": 14,
            "delivery_id": "10000000-0000-4000-8000-000000000002", "pod_uid": "pod", "spec_sha256": "spec"}


class ProducerContracts(unittest.TestCase):
    def setUp(self):
        self.ci = patch.object(producer, "verify_ci", return_value={"check": 1, "build": 2, "smoke": 3}).start()
        self.install = patch.object(producer, "installation", return_value=IDENTITY).start()
        self.addCleanup(patch.stopall)
        self.probes = Mock(return_value=list(producer.CHECKS))
        self.key = Mock()
        self.key.sign.return_value = b"s" * 64

    def collect(self, **kwargs):
        return producer.collect(123, DIGEST, HEAD, self.probes, clock=Mock(side_effect=[1000, 1010]), **kwargs)

    def test_unsigned_is_not_an_importable_envelope(self):
        result = self.collect()
        self.assertEqual(result["kind"], "unsigned-installed-test-collection")
        self.assertNotIn("payload", result)
        self.assertNotIn("signature", result)
        self.assertEqual(result["candidate"]["checks"], producer.CHECKS)

    def test_signed_exact_wire_domain_and_fresh_expiry(self):
        result = self.collect(key=self.key)
        self.assertEqual(set(result), {"payload", "signature"})
        self.key.sign.assert_called_once_with(producer.DOMAIN + producer.canonical(result["payload"]))
        self.assertEqual(result["payload"]["observed_at"], 1010)
        self.assertEqual(result["payload"]["expires_at"], 1910)
        self.assertEqual(result["payload"]["delivery_id"], IDENTITY["delivery_id"])
        self.assertEqual(self.install.call_count, 3)
        self.assertEqual(self.ci.call_count, 2)
        self.probes.assert_called_once_with(IDENTITY["delivery_id"], DIGEST, HEAD, producer.PIPELINE + "123")

    def test_every_installation_fence_is_enforced(self):
        for field in IDENTITY:
            with self.subTest(field=field):
                changed = dict(IDENTITY, **{field: "changed"})
                self.install.side_effect = [IDENTITY, changed]
                with self.assertRaises(producer.EvidenceError):
                    self.collect(key=self.key)
        self.key.sign.assert_not_called()

    def test_change_during_ci_recheck_prevents_signing(self):
        self.install.side_effect = [IDENTITY, IDENTITY, dict(IDENTITY, generation=15)]
        with self.assertRaises(producer.EvidenceError):
            self.collect(key=self.key)
        self.key.sign.assert_not_called()

    def test_failed_or_incomplete_or_reordered_checks_prevent_signing(self):
        for checks in ([], producer.CHECKS[:-1], list(reversed(producer.CHECKS)), producer.CHECKS + ["extra"]):
            self.probes.return_value = checks
            with self.assertRaises(producer.EvidenceError):
                self.collect(key=self.key)
        self.probes.side_effect = ValueError("cleanup failed")
        with self.assertRaises(ValueError):
            self.collect(key=self.key)
        self.key.sign.assert_not_called()

    def test_ci_change_prevents_signing(self):
        self.ci.side_effect = [{"build": 1}, {"build": 2}]
        with self.assertRaises(producer.EvidenceError):
            self.collect(key=self.key)
        self.key.sign.assert_not_called()

    def test_slow_or_backward_collection_prevents_signing(self):
        for end in (999, 1601):
            with self.assertRaises(producer.EvidenceError):
                producer.collect(123, DIGEST, HEAD, self.probes, self.key, Mock(side_effect=[1000, end]))
        self.key.sign.assert_not_called()

    def test_invalid_identifiers_fail_before_probes(self):
        for pipeline, digest, head in ((True, DIGEST, HEAD), (0, DIGEST, HEAD), (123, DIGEST.upper(), HEAD), (123, DIGEST, HEAD + "\n")):
            with self.assertRaises(producer.EvidenceError):
                producer.collect(pipeline, digest, head, self.probes, self.key)
        self.probes.assert_not_called()
        self.key.sign.assert_not_called()


class ExactCIContracts(unittest.TestCase):
    def setUp(self):
        self.pipeline = {"id": 123, "project_id": 83, "status": "success", "sha": HEAD,
                         "web_url": producer.PIPELINE + "123"}
        self.jobs = [{"id": i, "name": name, "status": "success", "allow_failure": False,
                      "commit": {"id": HEAD}, "pipeline": {"id": 123}}
                     for i, name in enumerate(("check", "build", "smoke"), 1)]
        self.artifact = {"head": HEAD, "pipeline_id": 123, "repository": producer.REPOSITORY,
                         "digest": DIGEST, "platforms": ["linux/amd64", "linux/arm64"]}

    def verify(self, jobs=None, artifact=None):
        with patch.object(producer, "gitlab", side_effect=[self.pipeline, jobs or self.jobs, artifact or self.artifact]):
            return producer.verify_ci(123, DIGEST, HEAD)

    def test_exact_required_jobs_and_multiarchitecture_receipt(self):
        self.assertEqual(self.verify(), {"check": 1, "build": 2, "smoke": 3})

    def test_wrong_job_commit_pipeline_status_optional_or_duplicate_refused(self):
        for key, value in (("commit", {"id": "c" * 40}), ("pipeline", {"id": 124}),
                           ("allow_failure", True), ("status", "failed")):
            jobs = copy.deepcopy(self.jobs)
            jobs[0][key] = value
            with self.assertRaises(producer.EvidenceError):
                self.verify(jobs=jobs)
        with self.assertRaises(producer.EvidenceError):
            self.verify(jobs=self.jobs + [self.jobs[0]])

    def test_wrong_or_single_arch_artifact_refused(self):
        for key, value in (("digest", "sha256:" + "c" * 64), ("head", "c" * 40),
                           ("repository", "other"), ("pipeline_id", 124), ("platforms", ["linux/amd64"])):
            artifact = dict(self.artifact, **{key: value})
            with self.assertRaises(producer.EvidenceError):
                self.verify(artifact=artifact)


class InstallationContracts(unittest.TestCase):
    def setUp(self):
        self.template = {"metadata": {"annotations": {"joyride.nest/delivery-id": IDENTITY["delivery_id"]}},
                         "spec": {group: [{"name": name, "image": producer.REPOSITORY + "@" + DIGEST} for name in names]
                                  for group, names in (("containers", ["web", "ops", "worker", "trusted-test"]),
                                                       ("initContainers", ["migrate", "basemap"]))}}
        self.deployment = {"metadata": {"namespace": "test", "name": "joyride-test", "uid": IDENTITY["deployment_uid"], "generation": 14},
                           "spec": {"replicas": 1, "strategy": {"type": "Recreate"}, "template": self.template},
                           "status": dict.fromkeys(["replicas", "updatedReplicas", "availableReplicas", "readyReplicas"], 1)}
        self.deployment["status"]["observedGeneration"] = 14
        self.replica = {"metadata": {"uid": "replicaset", "ownerReferences": [{"controller": True, "uid": IDENTITY["deployment_uid"]}]},
                        "spec": {"replicas": 1, "template": copy.deepcopy(self.template)}}
        self.pod = {"metadata": {"uid": "pod", "ownerReferences": [{"controller": True, "uid": "replicaset"}]},
                    "spec": copy.deepcopy(self.template["spec"]),
                    "status": {"phase": "Running", "conditions": [{"type": "Ready", "status": "True"}]}}
        for group, spec_group in (("containerStatuses", "containers"), ("initContainerStatuses", "initContainers")):
            self.pod["status"][group] = [{"name": c["name"], "imageID": "synthetic-image-id", "restartCount": 0,
                                          "ready": True, "state": {"running": {"startedAt": "synthetic"}} if group == "containerStatuses"
                                          else {"terminated": {"exitCode": 0}}} for c in self.pod["spec"][spec_group]]

    def verify(self):
        with patch.object(producer, "kube", side_effect=[self.deployment, {"items": [self.replica]}, {"items": [self.pod]}]):
            return producer.installation(DIGEST)

    def test_current_pod_and_all_six_images_are_bound(self):
        self.assertEqual(self.verify()["generation"], 14)

    def test_mixed_image_or_missing_container_refused(self):
        self.template["spec"]["containers"][0]["image"] = producer.REPOSITORY + "@sha256:" + "c" * 64
        with self.assertRaises(producer.EvidenceError):
            self.verify()
        self.template["spec"]["containers"].pop()
        with self.assertRaises(producer.EvidenceError):
            self.verify()

    def test_old_ready_status_is_not_new_generation_proof(self):
        self.deployment["metadata"]["generation"] = 15
        with self.assertRaises(producer.EvidenceError):
            self.verify()

    def test_unowned_or_terminating_pod_refused(self):
        self.pod["metadata"]["ownerReferences"][0]["uid"] = "unrelated"
        with self.assertRaises(producer.EvidenceError):
            self.verify()
        self.pod["metadata"]["ownerReferences"][0]["uid"] = "replicaset"
        self.pod["metadata"]["deletionTimestamp"] = "synthetic"
        with self.assertRaises(producer.EvidenceError):
            self.verify()

    def test_pod_image_or_ready_mismatch_refused(self):
        self.pod["status"]["conditions"][0]["status"] = "False"
        with self.assertRaises(producer.EvidenceError):
            self.verify()
        self.pod["status"]["conditions"][0]["status"] = "True"
        self.pod["spec"]["initContainers"][0]["image"] = "other"
        with self.assertRaises(producer.EvidenceError):
            self.verify()


class ProbeCleanupContracts(unittest.TestCase):
    def test_partial_setup_failure_attempts_exact_cleanup(self):
        spec = importlib.util.spec_from_file_location("probes", ROOT / "files/app/joyride/installed_test_probes.py")
        assert spec is not None and spec.loader is not None
        probes = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(probes)
        with patch.object(probes, "manage", side_effect=[{"preflight": True}, ValueError("synthetic partial setup failure"), {"exact_cleanup": True}]) as manage:
            with self.assertRaises(ValueError):
                probes.run(IDENTITY["delivery_id"], DIGEST, HEAD, producer.PIPELINE + "123")
            self.assertEqual(manage.call_count, 3)
            cleanup = manage.call_args.args[0]
            self.assertIn("Session.objects.filter(session_key=session_id).delete()", cleanup)
            self.assertIn("settings.PRIVATE_ROOT/'derivatives'/photo_id", cleanup)
            self.assertNotIn(".all().delete()", cleanup)


class PrivateOutputContracts(unittest.TestCase):
    def test_private_exclusive_output_and_no_overwrite(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "receipt.json"
            producer.write_private(path, {"synthetic": True})
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            self.assertEqual(json.loads(path.read_text()), {"synthetic": True})
            with self.assertRaises(FileExistsError):
                producer.write_private(path, {"replacement": True})
            self.assertEqual(json.loads(path.read_text()), {"synthetic": True})

    def test_real_ed25519_roundtrip_with_disposable_memory_key(self):
        from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
        key = Ed25519PrivateKey.generate()
        data = producer.DOMAIN + producer.canonical({"explicit_synthetic_fixture": True})
        key.public_key().verify(key.sign(data), data)
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "synthetic-key"
            path.write_bytes(key.private_bytes_raw())
            path.chmod(0o600)
            loaded = producer.private_key(path)
            key.public_key().verify(loaded.sign(data), data)
            path.chmod(0o640)
            with self.assertRaises(producer.EvidenceError):
                producer.private_key(path)
            path.chmod(0o600)
            link = Path(folder) / "link"
            link.symlink_to(path)
            with self.assertRaises(OSError):
                producer.private_key(link)
            os.link(path, Path(folder) / "hardlink")
            with self.assertRaises(producer.EvidenceError):
                producer.private_key(path)


if __name__ == "__main__":
    unittest.main()
