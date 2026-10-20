"""Trusted Nest-side installed TEST collector; never run inside an app image.

No caller-provided check list or old receipt can be signed. Every invocation
rechecks exact CI, installation and HTTPS behavior, then optionally signs once.
This tool is not Joy approval, a production importer or a deployment controller.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import time
import uuid

REPOSITORY = "registry.gitlab.joyfullee.me/joy/joyride/app"
PIPELINE = "https://gitlab.joyfullee.me/joy/joyride/-/pipelines/"
CHECKS = ["https_readiness", "session_csrf", "disabled_billing",
          "private_route_photo_gpx", "photo_only", "basemap_range"]
DOMAIN = b"joyride-installed-test-v1\x00"


class EvidenceError(Exception):
    """Only fixed safe errors may cross the command boundary."""


def require(value):
    if not value:
        raise EvidenceError("installed_test_collection_failed")


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"),
                      ensure_ascii=False, allow_nan=False).encode("utf-8")


def command(argv, limit=1048576):
    result = subprocess.run(argv, capture_output=True, timeout=60, check=False)
    require(result.returncode == 0 and len(result.stdout) <= limit)
    return result.stdout


def kube(*args):
    return json.loads(command(["kubectl", "-n", "test", *args, "-o", "json"]))


def gitlab(path):
    return json.loads(command(["glab", "api", "projects/83/" + path]))


def verify_ci(pipeline_id, digest, head):
    pipeline = gitlab(f"pipelines/{pipeline_id}")
    require(pipeline.get("id") == pipeline_id and pipeline.get("project_id") == 83
            and pipeline.get("sha") == head and pipeline.get("status") == "success"
            and pipeline.get("web_url") == PIPELINE + str(pipeline_id))
    jobs = gitlab(f"pipelines/{pipeline_id}/jobs?per_page=100")
    require(isinstance(jobs, list) and 0 < len(jobs) < 100)
    selected = {}
    for name in ("check", "build", "smoke"):
        matches = [j for j in jobs if j.get("name") == name]
        require(len(matches) == 1)
        job = matches[0]
        require(job.get("status") == "success" and job.get("allow_failure") is False
                and job.get("commit", {}).get("id") == head
                and job.get("pipeline", {}).get("id") == pipeline_id)
        selected[name] = job["id"]
    artifact = gitlab(f"jobs/{selected['build']}/artifacts/image.json")
    require(artifact.get("head") == head and artifact.get("pipeline_id") == pipeline_id
            and artifact.get("repository") == REPOSITORY and artifact.get("digest") == digest
            and sorted(artifact.get("platforms", [])) == ["linux/amd64", "linux/arm64"])
    return selected


def installation(digest):
    deployment = kube("get", "deployment", "joyride-test")
    metadata, spec, status = deployment["metadata"], deployment["spec"], deployment["status"]
    require(metadata.get("namespace") == "test" and metadata.get("name") == "joyride-test")
    require(str(uuid.UUID(metadata["uid"])) == metadata["uid"])
    require(type(metadata["generation"]) is int and metadata["generation"] > 0)
    require(spec.get("replicas") == 1 and spec.get("strategy", {}).get("type") == "Recreate")
    require(status.get("observedGeneration") == metadata["generation"])
    require(all(status.get(k) == 1 for k in ("replicas", "updatedReplicas", "readyReplicas", "availableReplicas")))
    require(status.get("unavailableReplicas", 0) == 0)
    template = spec["template"]
    delivery_id = template.get("metadata", {}).get("annotations", {}).get("joyride.nest/delivery-id")
    require(str(uuid.UUID(delivery_id)) == delivery_id)
    for group, names in (("containers", {"web", "ops", "worker", "trusted-test"}),
                         ("initContainers", {"migrate", "basemap"})):
        rows = template["spec"][group]
        require(len(rows) == len(names) and {row["name"] for row in rows} == names)
        require(all(row["image"] == REPOSITORY + "@" + digest for row in rows))
    # Bind actual ready pods to the current Deployment-owned ReplicaSet, not just
    # a ready status retained from an older generation or an unrelated selector.
    replicas = kube("get", "replicasets", "-l", "app=joyride-test")["items"]
    owners = {r["metadata"]["uid"] for r in replicas if any(
        o.get("uid") == metadata["uid"] and o.get("controller") is True
        for o in r["metadata"].get("ownerReferences", []))
        and r["spec"]["template"].get("metadata", {}).get("annotations", {}).get("joyride.nest/delivery-id") == delivery_id
        and r["spec"].get("replicas") == 1}
    require(len(owners) == 1)
    pods = [p for p in kube("get", "pods", "-l", "app=joyride-test")["items"] if any(
        o.get("uid") in owners and o.get("controller") is True
        for o in p["metadata"].get("ownerReferences", [])) and not p["metadata"].get("deletionTimestamp")]
    require(len(pods) == 1)
    pod = pods[0]
    require(pod["status"].get("phase") == "Running")
    require(any(c.get("type") == "Ready" and c.get("status") == "True"
                for c in pod["status"].get("conditions", [])))
    for group in ("containers", "initContainers"):
        require(pod["spec"][group] == template["spec"][group])
    runtime = []
    for group, spec_group in (("containerStatuses", "containers"), ("initContainerStatuses", "initContainers")):
        rows = pod["status"].get(group, [])
        require(len(rows) == len(pod["spec"][spec_group])
                and {row["name"] for row in rows} == {row["name"] for row in pod["spec"][spec_group]})
        for row in rows:
            require(type(row.get("restartCount")) is int and row["restartCount"] >= 0 and bool(row.get("imageID")))
            if group == "containerStatuses":
                require(row.get("ready") is True and bool(row.get("state", {}).get("running")))
            else:
                require(row.get("state", {}).get("terminated", {}).get("exitCode") == 0)
            runtime.append({"name": row["name"], "imageID": row["imageID"],
                            "restartCount": row["restartCount"], "state": row["state"]})
    # ResourceVersion includes harmless status changes; full spec and pod UID are
    # stable fences. Both snapshots must agree after probes and cleanup.
    return {"deployment_uid": metadata["uid"], "generation": metadata["generation"],
            "delivery_id": delivery_id, "pod_uid": pod["metadata"]["uid"],
            "runtime_sha256": hashlib.sha256(canonical(sorted(runtime, key=lambda row: row["name"]))).hexdigest(),
            "spec_sha256": hashlib.sha256(canonical(spec)).hexdigest()}


def private_key(path):
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    try:
        metadata = os.fstat(fd)
        require(stat.S_ISREG(metadata.st_mode) and stat.S_IMODE(metadata.st_mode) == 0o600
                and metadata.st_uid == os.geteuid() and metadata.st_nlink == 1)
        value = os.read(fd, 65)
        require(len(value) == 32)
        return Ed25519PrivateKey.from_private_bytes(value)
    finally:
        os.close(fd)


def collect(pipeline_id, digest, head, probes, key=None, clock=time.time):
    require(type(pipeline_id) is int and pipeline_id > 0)
    require(isinstance(digest, str) and re.fullmatch(r"sha256:[0-9a-f]{64}", digest))
    require(isinstance(head, str) and re.fullmatch(r"[0-9a-f]{40}", head))
    started = int(clock())
    jobs = verify_ci(pipeline_id, digest, head)
    before = installation(digest)
    # Probe implementation is trusted Nest source, not caller input or app code.
    # It validates the terminal delivery row independently and removes exact
    # synthetic fixtures in finally before any receipt can be signed.
    require(probes(before["delivery_id"], digest, head, PIPELINE + str(pipeline_id)) == CHECKS)
    after = installation(digest)
    require(before == after)
    require(verify_ci(pipeline_id, digest, head) == jobs)
    require(installation(digest) == before)
    observed = int(clock())
    require(0 <= observed - started <= 600)
    payload = {"schema": 1, "kind": "joyride-installed-test-v1", "receipt_id": str(uuid.uuid4()),
               "repository": REPOSITORY, "digest": digest, "source_head": head,
               "pipeline_url": PIPELINE + str(pipeline_id), "namespace": "test", "deployment": "joyride-test",
               "deployment_uid": before["deployment_uid"], "generation": before["generation"],
               "delivery_id": before["delivery_id"], "observed_at": observed,
               "expires_at": observed + 900, "checks": list(CHECKS)}
    if key is None:
        # Deliberately not a consumer envelope; unsigned diagnostics cannot import.
        return {"kind": "unsigned-installed-test-collection", "candidate": payload,
                "jobs": jobs, "installation": before}
    return {"payload": payload, "signature": key.sign(DOMAIN + canonical(payload)).hex()}


def write_private(path, value):
    data = canonical(value) + b"\n"
    require(len(data) <= 16384)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
    except BaseException:
        os.unlink(path)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pipeline", type=int, required=True)
    parser.add_argument("--digest", required=True)
    parser.add_argument("--source-head", required=True)
    parser.add_argument("--output", type=Path, required=True)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--collect-only", action="store_true")
    mode.add_argument("--signing-key", type=Path)
    args = parser.parse_args()
    # Fail before mutation when output already exists or key is unsafe/missing.
    require(not args.output.exists() and not args.output.is_symlink())
    key = private_key(args.signing_key) if args.signing_key else None
    from installed_test_probes import run
    result = collect(args.pipeline, args.digest, args.source_head, run, key)
    write_private(args.output, result)
    print("Installed TEST collection complete; signed" if key else "Installed TEST collection complete; unsigned, not importable")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print("Installed TEST collection failed; no acceptance claimed", file=sys.stderr)
        sys.exit(1)
