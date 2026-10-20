"""Ephemeral RBAC boundary fixtures. No real credentials or cluster access."""
import copy
from datetime import datetime, timezone
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
SPEC = importlib.util.spec_from_file_location("evidence_identity", ROOT / "files/app/joyride/evidence_identity.py")
assert SPEC is not None and SPEC.loader is not None
identity = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(identity)
POD = "joyride-test-76677fdf79-wx6lb"
UID = "10000000-0000-4000-8000-000000000001"


class TargetBinding(unittest.TestCase):
    def setUp(self):
        self.reset_target()
        self.api = patch.object(identity, "command", side_effect=self.read).start()
        self.addCleanup(patch.stopall)

    def reset_target(self):
        image = "registry.gitlab.joyfullee.me/joy/joyride/app@sha256:" + "a" * 64
        self.deployment = {
            "metadata": {"name": "joyride-test", "namespace": "test", "uid": UID, "generation": 2},
            "spec": {"replicas": 1, "strategy": {"type": "Recreate"}, "template": {
                "metadata": {"annotations": {"joyride.nest/delivery-id": UID}},
                "spec": {"containers": [{"name": name, "image": image}
                                        for name in ("web", "ops", "worker", "trusted-test")],
                         "initContainers": [{"name": name, "image": image}
                                            for name in ("migrate", "basemap")]}}},
            "status": {"observedGeneration": 2, "replicas": 1, "updatedReplicas": 1,
                       "readyReplicas": 1, "availableReplicas": 1}}
        self.replica = {"metadata": {"uid": UID, "ownerReferences": [
            {"kind": "Deployment", "uid": UID, "controller": True}]},
            "spec": {"replicas": 1, "template": copy.deepcopy(self.deployment["spec"]["template"])}}
        self.pod = {"metadata": {"name": POD, "namespace": "test", "uid": UID,
                                 "ownerReferences": [{"kind": "ReplicaSet", "uid": UID, "controller": True}]},
                    "spec": copy.deepcopy(self.deployment["spec"]["template"]["spec"]),
                    "status": {"phase": "Running", "conditions": [{"type": "Ready", "status": "True"}]}}

    def read(self, args):
        if args[1] == "deployment":
            return self.deployment
        if args[1] == "replicasets":
            return {"items": [self.replica]}
        if args[1] == "pods":
            return {"items": [self.pod]}
        raise AssertionError(args)

    def test_binding_runs_without_application_module(self):
        # Real binding path, not IdentityContracts' provisioning mock. The
        # application producer no longer exists on the Nest import path.
        result = identity.bind_target(POD)
        self.assertEqual(result["pod_uid"], UID)
        self.assertEqual(result["deployment_uid"], UID)
        self.assertEqual(result["generation"], 2)

    def test_stale_or_unrelated_target_is_refused(self):
        mutations = (
            lambda: self.deployment["status"].update(observedGeneration=1),
            lambda: self.replica["metadata"]["ownerReferences"][0].update(uid="other"),
            lambda: self.pod["metadata"].update(name=POD + "other"),
            lambda: self.pod["metadata"].update(deletionTimestamp="now"),
            lambda: self.pod["status"].update(conditions=[]),
            lambda: self.pod["spec"]["containers"][0].update(image="unreviewed:latest"),
            lambda: self.deployment["spec"]["template"]["spec"]["containers"][0].update(image="unreviewed:latest"),
            lambda: self.replica["metadata"]["ownerReferences"][0].update(kind="StatefulSet"),
            lambda: self.pod["metadata"]["ownerReferences"][0].update(controller=False),
            lambda: self.pod["metadata"].update(namespace="joyride"),
        )
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                self.reset_target()
                mutate()
                with self.assertRaises(ValueError):
                    identity.bind_target(POD)

    def test_duplicate_live_pod_is_refused(self):
        original = self.read
        def read(args):
            result = original(args)
            if args[1] == "pods":
                result["items"].append(copy.deepcopy(self.pod))
            return result
        self.api.side_effect = read
        with self.assertRaises(ValueError):
            identity.bind_target(POD)

    def test_binding_does_not_load_application_or_signer_modules(self):
        import ast
        tree = ast.parse((ROOT / "files/app/joyride/evidence_identity.py").read_text())
        imports = {node.module for node in ast.walk(tree) if isinstance(node, ast.ImportFrom)}
        self.assertFalse(imports.intersection({"installed_test_producer", "evidence_key", "django"}))


class IdentityContracts(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.directory = Path(self.tmp.name)
        self.client = identity.Identity(self.directory, POD)
        self.calls = []
        self.objects = {}
        self.grant_extra = False
        self.expiry = 900
        self.transport = {"server": identity.SERVER, "certificate-authority-data": "public-ca"}
        self.bind = patch.object(identity, "bind_target", return_value={"pod_uid": UID}).start()
        self.command = patch.object(identity, "command", side_effect=self.api).start()
        self.addCleanup(patch.stopall)

    def api(self, args, body=None, config=None):
        self.calls.append((args, copy.deepcopy(body), config))
        if args[0] == "config":
            return {"clusters": [{"name": "eyrie", "cluster": self.transport}],
                    "users": [{"user": {"client-key-data": "operator-must-not-be-copied"}}]}
        if args[0:2] == ["get", "--raw"]:
            return self.objects[args[2]]
        if args[0:2] == ["create", "-f"]:
            result = copy.deepcopy(body)
            result["metadata"]["uid"] = UID
            self.objects[identity.resource_path(body)] = result
            return result
        if args[0:2] == ["delete", "--raw"]:
            self.assertEqual(body["preconditions"], {"uid": UID})
            del self.objects[args[2]]
            return {"status": "Success"}
        if args[0] == "get" and "--ignore-not-found" in args:
            return {}
        if args[2].endswith("/token"):
            return {"status": {"token": "disposable-fixture-token",
                               "expirationTimestamp": datetime.fromtimestamp(
                                   time.time() + self.expiry, timezone.utc).isoformat()}}
        attributes = body["spec"]["resourceAttributes"]
        allowed = (attributes["namespace"] == "test" and (
            (attributes["resource"] == "deployments" and attributes["verb"] == "get") or
            (attributes["resource"] == "replicasets" and attributes["verb"] == "list") or
            (attributes["resource"] == "pods" and (
                attributes["verb"] == "list" or attributes.get("name") == POD))))
        return {"status": {"allowed": allowed or self.grant_extra}}

    def test_exact_role_and_no_namespace_wide_exec(self):
        docs = identity.resources("a" * 32, POD)
        self.assertEqual([x["kind"] for x in docs], ["ServiceAccount", "Role", "RoleBinding"])
        self.assertFalse(docs[0]["automountServiceAccountToken"])
        rules = docs[1]["rules"]
        self.assertEqual(rules[-1], {"apiGroups": [""], "resources": ["pods/exec"],
                                     "verbs": ["create"], "resourceNames": [POD]})
        self.assertFalse(any("*" in str(r) for r in rules))
        self.assertFalse(any("secrets" in str(r) for r in rules))
        self.assertEqual(docs[2]["subjects"][0]["namespace"], "test")

    def test_provision_verify_and_exact_uid_revocation(self):
        config = self.client.provision()
        data = json.loads(config.read_text())
        self.assertNotIn("operator-must-not-be-copied", config.read_text())
        self.assertEqual(data["users"], [{"name": "evidence", "user": {"token": "disposable-fixture-token"}}])
        self.assertEqual(config.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.client.verify(), 16)
        self.client.revoke()
        self.assertFalse(config.exists())
        self.assertFalse(self.objects)
        self.assertTrue(json.loads((self.directory / "revoked.json").read_text())["revoked"])
        deletes = [c for c in self.calls if c[0][0] == "delete"]
        self.assertEqual(len(deletes), 3)
        self.assertIn("serviceaccounts/", deletes[0][0][2])

    def test_reject_ambient_authority(self):
        self.client.provision()
        self.grant_extra = True
        with self.assertRaises(ValueError):
            self.client.verify()
        self.assertTrue(self.client.config.exists())
        self.assertFalse((self.directory / "revoked.json").exists())

    def test_reject_long_or_expired_token_before_writing(self):
        self.expiry = 3600
        with self.assertRaises(ValueError):
            self.client.provision()
        self.assertFalse(self.client.config.exists())
        self.assertTrue(self.objects)
        self.assertTrue(self.client.journal.exists())

    def test_reject_transport_override_before_mutation(self):
        self.transport["insecure-skip-tls-verify"] = True
        with self.assertRaises(ValueError):
            self.client.provision()
        self.assertFalse(self.objects)

    def test_target_mismatch_prevents_mutation(self):
        self.bind.side_effect = ValueError("not the installed pod")
        with self.assertRaises(ValueError):
            self.client.provision()
        self.command.assert_not_called()

    def test_readback_change_fails_and_keeps_exact_journal(self):
        original = self.api
        def api(args, body=None, config=None):
            result = original(args, body, config)
            if args[0:2] == ["get", "--raw"] and "roles/" in args[2]:
                result["rules"] = []
            return result
        self.command.side_effect = api
        with self.assertRaises(ValueError):
            self.client.provision()
        self.assertFalse(self.client.config.exists())
        self.assertEqual(len(self.client.created), 2)
        with self.assertRaises(ValueError):
            self.client.revoke()
        self.assertTrue(self.client.journal.exists())

    def test_uncertain_create_is_not_retried_or_deleted(self):
        original = self.api
        def api(args, body=None, config=None):
            result = original(args, body, config)
            if args[0:2] == ["create", "-f"]:
                raise TimeoutError("ambiguous create")
            return result
        self.command.side_effect = api
        with self.assertRaises(TimeoutError):
            self.client.provision()
        self.assertEqual(len(self.objects), 1)
        self.assertFalse(self.client.created)
        self.assertFalse(any(c[0][0] == "delete" for c in self.calls))
        self.assertTrue(self.client.journal.exists())

    def test_cleanup_uncertainty_preserves_config_and_no_success(self):
        self.client.provision()
        self.command.side_effect = TimeoutError("ambiguous delete")
        with self.assertRaises(TimeoutError):
            self.client.revoke()
        self.assertTrue(self.client.config.exists())
        self.assertFalse((self.directory / "revoked.json").exists())

    def test_existing_and_unsafe_paths_are_not_reused(self):
        with self.assertRaises(FileExistsError):
            identity.Identity(self.directory, POD)
        os.chmod(self.directory, 0o755)
        with self.assertRaises(ValueError):
            identity.Identity(self.directory, POD)
        os.chmod(self.directory, 0o700)
        link = self.directory / "link"
        link.symlink_to(self.directory, target_is_directory=True)
        with self.assertRaises(ValueError):
            identity.private_directory(link)

    def test_malformed_resource_selectors_are_refused(self):
        for session, pod in (("A" * 32, POD), ("a" * 32, "other-pod"), ("a" * 32, POD + "\n")):
            with self.assertRaises(ValueError):
                identity.resources(session, pod)


if __name__ == "__main__":
    unittest.main()
