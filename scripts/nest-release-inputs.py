#!/usr/bin/env python3
"""Retain reviewed frozen expectations in config CI; never build or trigger."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys

release = runpy.run_path(str(Path(__file__).with_name("nest-release-manifest.py")))
require = release["require"]


def identity(env, checkout):
    require(env.get("RELEASE_INPUTS") == "true", "release input mode required")
    require(not any(env.get(k) for k in ("BUILD", "EXECUTOR_ONLY", "RELEASE_CANDIDATE", "RELEASE_VALIDATE_ONLY")),
            "conflicting pipeline mode")
    require(env.get("CI_PROJECT_PATH") == "nest/config" and env.get("CI_PROJECT_ID") == "3",
            "wrong input producer project")
    source = env.get("CI_COMMIT_SHA", "")
    release["match"](source, release["SHA"], "CI source")
    for key in ("CI_PIPELINE_ID", "CI_JOB_ID"):
        release["match"](env.get(key, ""), r"[1-9][0-9]{0,19}", "CI numeric identity")
    require(checkout.is_absolute() and checkout.resolve() == checkout and checkout.is_dir(),
            "invalid checkout path")

    def git(*args):
        return subprocess.check_output(["git", "-C", str(checkout), *args], stderr=subprocess.DEVNULL,
                                       timeout=30).decode("ascii").strip()

    require(git("rev-parse", "HEAD") == source, "CI checkout source mismatch")
    require(not git("status", "--porcelain", "--untracked-files=no"), "modified CI checkout")
    return source


def identity_trust(expected, checkout, source):
    """Select public CA pins from exact config source, never the private input."""
    members = [row for row in expected["members"] if row["stage"] == "stage3"]
    if not members:
        return None
    # Reading the Git object avoids untracked/ignored policy substitution. The
    # already checked source and ordinary reviewed GitLab publication are the
    # trust boundary; this is not cryptographic owner-approval attestation.
    raw = subprocess.check_output(["git", "-C", str(checkout), "show", source + ":data/release/trust.json"],
                                  stderr=subprocess.DEVNULL, timeout=30)
    require(len(raw) <= release["LIMIT"], "trust policy exceeds size limit")
    policy = json.loads(raw, object_pairs_hook=release["unique_object"], parse_int=release["json_integer"],
                        parse_constant=lambda _: (_ for _ in ()).throw(ValueError("invalid trust number")))
    release["fields"](policy, "schema kind hosts", "identity trust policy")
    require(type(policy["schema"]) is int and policy["schema"] == 1
            and policy["kind"] == "nest_release_identity_trust", "unsupported identity trust policy")
    hosts = policy["hosts"]
    require(type(hosts) is dict and len(hosts) <= 1024, "invalid identity trust inventory")
    for host, pin in hosts.items():
        release["match"](host, release["TOKEN"], "trust host")
        release["match"](pin, r"[0-9a-f]{64}", "trusted public CA pin")
    for member in members:
        require(member["host"] in hosts and hosts[member["host"]] == member["identity_ca_sha256"],
                "Stage 3 identity trust does not match reviewed config policy")
    return release["canonical"](policy)


def publish(input_path, env):
    checkout = Path(env.get("CI_PROJECT_DIR", ""))
    source = identity(env, checkout)
    input_path = Path(input_path)
    require(input_path.is_file() and not input_path.is_symlink(), "invalid expectations file")
    expected = release["load"](input_path)
    release["expectations"](expected)
    require(expected["sources"]["nest/config"] == source, "expectations use another config source")
    trust = identity_trust(expected, checkout, source)
    payload = release["canonical"](expected)
    require(len(payload) <= release["LIMIT"], "canonical expectations exceed size limit")
    raw_sha = hashlib.sha256(payload).hexdigest()
    receipt = {
        "schema": 1, "kind": "nest_release_input_publication",
        "release": expected["release"], "expectations_digest": release["digest"](expected),
        "artifact": "release-inputs/expectations.json", "artifact_sha256": raw_sha,
        "producer": {"project": "nest/config", "sha": source,
                     "pipeline": int(env["CI_PIPELINE_ID"]), "job": int(env["CI_JOB_ID"])},
        "resource_verification": "not_performed", "promotion_authorized": False,
    }
    # A fresh, private CI job directory is the publication boundary. Failure never
    # replaces an earlier artifact; on-success CI retention excludes partial output.
    destination = checkout / "release-inputs"
    destination.mkdir(mode=0o700)
    records = {"expectations.json": payload, "receipt.json": release["canonical"](receipt)}
    if trust is not None:
        records["trust.json"] = trust
    for name, data in records.items():
        with (destination / name).open("xb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
    descriptor = os.open(destination, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)
    for name, data in records.items():
        require((destination / name).read_bytes() == data, "input artifact readback failed")
    require(release["load"](destination / "expectations.json") == expected, "input artifact changed")
    require(identity(env, checkout) == source, "CI identity changed during publication")
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--expectations", required=True)
    args = parser.parse_args()
    try:
        receipt = publish(args.expectations, os.environ)
        # Do not echo user text, paths, reasons or private diagnostics into job logs.
        print(release["canonical"]({"schema": 1, "kind": "nest_release_input_readback",
                                    "artifact_sha256": receipt["artifact_sha256"],
                                    "readback_verified": True}).decode("ascii"), end="")
        return 0
    except (OSError, ValueError, KeyError, TypeError, RecursionError, subprocess.SubprocessError):
        print("Frozen release input publication refused or failed", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
