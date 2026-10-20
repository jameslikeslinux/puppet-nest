"""Trusted operator's ephemeral TEST identity; never include in the signer image.

Administrative provisioning stays outside the collector. No signing key is read.
An interrupted invocation leaves an exact journal for supervised recovery, never
an automatic namespace-wide cleanup. Run only from reviewed Nest source.
"""
import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import time
import uuid

LABEL = "joyride.nest/evidence-session"
SERVER = "https://control-plane.eyrie:6443"


def require(value):
    if not value:
        raise ValueError("evidence_identity_boundary_failed")


def command(args, body=None, config=None):
    argv = ["kubectl", "--request-timeout=20s"]
    if config is not None:
        argv += ["--kubeconfig", str(config)]
    result = subprocess.run(argv + args, input=json.dumps(body).encode() if body is not None else None,
                            capture_output=True, timeout=30, check=False)
    require(result.returncode == 0 and len(result.stdout) <= 1048576)
    if not result.stdout.strip() and "--ignore-not-found" in args:
        return {}
    return json.loads(result.stdout)


def resources(session, pod):
    require(re.fullmatch(r"[0-9a-f]{32}", session) is not None)
    require(re.fullmatch(r"joyride-test-[a-z0-9]+-[a-z0-9]+", pod) is not None)
    name = "joyride-evidence-" + session
    metadata = {"name": name, "namespace": "test", "labels": {LABEL: session}}
    return [
        {"apiVersion": "v1", "kind": "ServiceAccount", "metadata": metadata,
         "automountServiceAccountToken": False},
        {"apiVersion": "rbac.authorization.k8s.io/v1", "kind": "Role", "metadata": metadata,
         "rules": [
             {"apiGroups": ["apps"], "resources": ["deployments"], "verbs": ["get"],
              "resourceNames": ["joyride-test"]},
             # Kubernetes RBAC has no selector-aware list grant. Metadata lists
             # are TEST-namespace-wide; mutation/exec is NOT namespace-wide.
             {"apiGroups": ["apps"], "resources": ["replicasets"], "verbs": ["list"]},
             {"apiGroups": [""], "resources": ["pods"], "verbs": ["list"]},
             {"apiGroups": [""], "resources": ["pods"], "verbs": ["get"], "resourceNames": [pod]},
             {"apiGroups": [""], "resources": ["pods/exec"], "verbs": ["create"], "resourceNames": [pod]},
         ]},
        {"apiVersion": "rbac.authorization.k8s.io/v1", "kind": "RoleBinding", "metadata": metadata,
         "roleRef": {"apiGroup": "rbac.authorization.k8s.io", "kind": "Role", "name": name},
         "subjects": [{"kind": "ServiceAccount", "name": name, "namespace": "test"}]},
    ]


def resource_path(resource):
    kind = resource["kind"]
    prefix, plural = {"ServiceAccount": ("/api/v1", "serviceaccounts"),
                      "Role": ("/apis/rbac.authorization.k8s.io/v1", "roles"),
                      "RoleBinding": ("/apis/rbac.authorization.k8s.io/v1", "rolebindings")}[kind]
    return prefix + "/namespaces/test/" + plural + "/" + resource["metadata"]["name"]


def private_write(path, value):
    fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "w") as stream:
        json.dump(value, stream, sort_keys=True)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())


def private_directory(path):
    require(path.is_absolute())
    for ancestor in [*reversed(path.parents), path]:
        info = ancestor.lstat()
        require(stat.S_ISDIR(info.st_mode) and info.st_uid in (0, os.geteuid())
                and stat.S_IMODE(info.st_mode) & 0o022 == 0)
    require(path.stat().st_uid == os.geteuid() and stat.S_IMODE(path.stat().st_mode) == 0o700)


def bind_target(pod):
    deployment = command(["get", "deployment", "joyride-test", "-n", "test", "-o", "json"])
    image = deployment["spec"]["template"]["spec"]["containers"][0]["image"]
    require(image.startswith("registry.gitlab.joyfullee.me/joy/joyride/app@sha256:"))
    from installed_test_producer import installation
    installed = installation(image.split("@", 1)[1])
    actual = command(["get", "pod", pod, "-n", "test", "-o", "json"])
    require(actual["metadata"]["uid"] == installed["pod_uid"]
            and not actual["metadata"].get("deletionTimestamp"))
    return installed


class Identity:
    def __init__(self, directory, pod):
        private_directory(directory)
        self.directory = directory
        self.session = uuid.uuid4().hex
        self.resources = resources(self.session, pod)
        self.config = directory / "kubeconfig"
        self.journal = directory / "identity.json"
        require(not self.config.exists() and not self.config.is_symlink())
        private_write(self.journal, {"schema": 1, "session": self.session, "resources": self.resources})
        self.created = []

    def provision(self):
        installed = bind_target(self.resources[1]["rules"][-1]["resourceNames"][0])
        private_write(self.directory / "target.json", installed)
        # Read transport only. Do not flatten, inherit, write or mount the
        # operator's users, client certificate, exec plugin or impersonation.
        current = command(["config", "view", "--minify", "--flatten", "-o", "json"])
        require(len(current["clusters"]) == 1)
        cluster = current["clusters"][0]["cluster"]
        require(set(cluster) == {"server", "certificate-authority-data"}
                and cluster["server"] == SERVER and bool(cluster["certificate-authority-data"]))
        for resource in self.resources:
            # Intent is durable before the create. A timeout is not proof the
            # create failed; preserve journal and refuse a blind retry.
            result = command(["create", "-f", "-", "-o", "json"], resource)
            require(result["metadata"].get("labels", {}).get(LABEL) == self.session)
            uid = str(uuid.UUID(result["metadata"]["uid"]))
            self.created.append((resource, uid))
            private_write(self.directory / (resource["kind"] + ".json"),
                          {"uid": uid, "resource": resource})
            actual = command(["get", "--raw", resource_path(resource)])
            require(actual["metadata"]["uid"] == uid)
            for key in ("rules", "roleRef", "subjects", "automountServiceAccountToken"):
                if key in resource:
                    require(actual.get(key) == resource[key])
        token = command(["create", "--raw", resource_path(self.resources[0]) + "/token", "-f", "-"],
                        {"apiVersion": "authentication.k8s.io/v1", "kind": "TokenRequest",
                         "spec": {"audiences": [], "expirationSeconds": 900}})
        expires = datetime.fromisoformat(token["status"]["expirationTimestamp"].replace("Z", "+00:00"))
        require(0 < expires.timestamp() - time.time() <= 960)
        value = token["status"]["token"]
        require(isinstance(value, str) and 0 < len(value) < 16384)
        private_write(self.config, {"apiVersion": "v1", "kind": "Config",
                                   "clusters": [{"name": "eyrie", "cluster": cluster}],
                                   "users": [{"name": "evidence", "user": {"token": value}}],
                                   "contexts": [{"name": "evidence", "context": {
                                       "cluster": "eyrie", "user": "evidence", "namespace": "test"}}],
                                   "current-context": "evidence"})
        return self.config

    def verify(self):
        pod = self.resources[1]["rules"][-1]["resourceNames"][0]
        # Check real effective authority, including unexpected ambient grants.
        checks = [(True, "test", "apps", "deployments", "get", "joyride-test", ""),
                  (True, "test", "apps", "replicasets", "list", "", ""),
                  (True, "test", "", "pods", "list", "", ""),
                  (True, "test", "", "pods", "get", pod, ""),
                  (True, "test", "", "pods", "create", pod, "exec"),
                  (False, "test", "", "pods", "create", "another-pod", "exec"),
                  (False, "test", "", "secrets", "get", "joyride-test-runtime", ""),
                  (False, "test", "", "secrets", "list", "", ""),
                  (False, "test", "apps", "deployments", "patch", "joyride-test", ""),
                  (False, "test", "", "pods", "create", "", ""),
                  (False, "test", "rbac.authorization.k8s.io", "roles", "create", "", ""),
                  (False, "test", "", "serviceaccounts", "create", "", "token"),
                  (False, "joyride", "apps", "deployments", "get", "joyride", ""),
                  (False, "joyride", "", "pods", "create", pod, "exec"),
                  (False, "kube-system", "", "secrets", "list", "", ""),
                  (False, "", "", "nodes", "list", "", "")]
        for expected, namespace, group, resource, verb, name, subresource in checks:
            attributes = {"namespace": namespace, "group": group, "resource": resource, "verb": verb}
            if name:
                attributes["name"] = name
            if subresource:
                attributes["subresource"] = subresource
            result = command(["create", "--raw", "/apis/authorization.k8s.io/v1/selfsubjectaccessreviews", "-f", "-"],
                             {"apiVersion": "authorization.k8s.io/v1", "kind": "SelfSubjectAccessReview",
                              "spec": {"resourceAttributes": attributes}}, config=self.config)
            require(result["status"].get("allowed") is expected
                    and not result["status"].get("evaluationError"))
        return len(checks)

    def revoke(self):
        # UID-preconditioned exact deletes, never selector/name-only deletes.
        # SA first invalidates its TokenRequest token. Preserve all state on any
        # uncertainty so an operator can reconcile it from the exact journal.
        require(len(self.created) == len(self.resources))
        for resource, uid in self.created:
            path = resource_path(resource)
            command(["delete", "--raw", path, "-f", "-"],
                    {"apiVersion": "v1", "kind": "DeleteOptions", "preconditions": {"uid": uid}})
            remaining = command(["get", resource["kind"], "-n", "test", resource["metadata"]["name"],
                                 "--ignore-not-found", "-o", "json"])
            require(not remaining)
        self.config.unlink(missing_ok=True)
        private_write(self.directory / "revoked.json", {"schema": 1, "session": self.session, "revoked": True})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--pod", required=True)
    args = parser.parse_args()
    identity = Identity(args.directory, args.pod)
    # Failures deliberately retain the journal. Do not report successful cleanup
    # or reuse an uncertain identity. No signing is available in this command.
    identity.provision()
    checks = identity.verify()
    identity.revoke()
    print(f"Ephemeral TEST identity: {checks} effective permission checks passed; exact resources revoked")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print("Evidence identity failed; preserve exact private journal for supervised recovery", file=sys.stderr)
        sys.exit(1)
