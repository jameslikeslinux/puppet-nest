"""Publish the approved static projection; no live credentials enter the image."""
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import tempfile

from release_evidence_runtime import identity, run

SOURCE = Path(__file__).resolve().parent
FILES = ("Containerfile.info", "informational_site.py", "informational/bundle-0.json", "informational/bundle-1.json")
REPOSITORY = "registry.eyrie/joy/joyride-info"


def publish(env, output):
    sha, pipeline, job = identity(env)
    if not env.get("EYRIE_REGISTRY_PASSWORD") or output.exists():
        raise ValueError("missing registry identity or existing receipt")
    root = SOURCE.parents[2]
    if run(["git", "-C", str(root), "rev-parse", "HEAD"]).strip() != sha:
        raise ValueError("checkout head mismatch")
    if run(["git", "-C", str(root), "status", "--porcelain", "--untracked-files=no"]).strip():
        raise ValueError("tracked source modified")
    hashes = {name: hashlib.sha256((SOURCE / name).read_bytes()).hexdigest() for name in FILES}
    tag = REPOSITORY + f":{sha}-{pipeline}-{job}"
    with tempfile.TemporaryDirectory(prefix="joyride-info-release-") as directory:
        folder = Path(directory)
        context = folder / "context"
        context.mkdir(mode=0o700)
        for name in FILES:
            target = context / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((SOURCE / name).read_bytes())
        auth = str(folder / "auth.json")
        digest_path = folder / "digest"
        try:
            run(["podman", "login", "--authfile", auth, "--username", "admin", "--password-stdin", "registry.eyrie"], input=env["EYRIE_REGISTRY_PASSWORD"])
            run(["podman", "build", "--authfile", auth, "--platform", "linux/amd64,linux/arm64", "--manifest", tag,
                 "--label", "org.opencontainers.image.revision=" + sha,
                 "--label", "me.joyfullee.joyride.frontend-source=73c0575179ab995979f9756c6be750f4903d4781",
                 "--file", str(context / "Containerfile.info"), str(context)])
            run(["podman", "manifest", "push", "--all", "--authfile", auth, "--digestfile", str(digest_path), tag, "docker://" + tag])
            digest = digest_path.read_text().strip()
            if not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
                raise ValueError("invalid registry digest")
            image = REPOSITORY + "@" + digest
            manifest = json.loads(run(["podman", "manifest", "inspect", "--authfile", auth, image]))
            if {item["platform"]["architecture"] for item in manifest["manifests"]} != {"amd64", "arm64"}:
                raise ValueError("incomplete platforms")
            run(["podman", "pull", "--authfile", auth, "--policy=always", image])
            # Run with no ambient mounts, network, authority or credentials.
            script = "import hashlib,json,pathlib; print(json.dumps({p:hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest() for p in ['/platform/server.py','/site/bundle-0.json','/site/bundle-1.json']}))"
            observed = json.loads(run(["podman", "run", "--rm", "--network=none", "--read-only", "--cap-drop=ALL", "--security-opt=no-new-privileges", image, "python", "-I", "-B", "-c", script]))
            expected = {"/platform/server.py": hashes["informational_site.py"], "/site/bundle-0.json": hashes["informational/bundle-0.json"], "/site/bundle-1.json": hashes["informational/bundle-1.json"]}
            if observed != expected:
                raise ValueError("published bytes differ")
            result = {"kind": "joyride-informational-release-v1", "source_head": sha, "frontend_source": "73c0575179ab995979f9756c6be750f4903d4781", "pipeline_id": pipeline, "job_id": job, "image": image, "platforms": ["linux/amd64", "linux/arm64"], "source_sha256": hashes}
        finally:
            run(["podman", "manifest", "rm", tag])
    with output.open("x") as stream:
        json.dump(result, stream, sort_keys=True, indent=2)
        stream.write("\n")
    return result


if __name__ == "__main__":
    try:
        print(json.dumps(publish(os.environ, Path(sys.argv[1])), sort_keys=True))
    except Exception:
        print("Informational publication failed; no verified release claimed.", file=sys.stderr)
        raise SystemExit(1)
