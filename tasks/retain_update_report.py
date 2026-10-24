#!/usr/bin/env python3
"""Materialize a bounded CLI report on the Bolt supervisor, never on the host."""

import hashlib
import json
import os
from pathlib import Path
import re
import sys
import tempfile


ID = r"[A-Za-z0-9][A-Za-z0-9_-]{0,63}"
DIGEST = r"[0-9a-f]{64}"
PHASES = ["backup", "mount", "sync", "kernel", "unmount", "activate"]


def require(condition, message):
    if not condition:
        raise ValueError(message)


def token(value, pattern):
    require(isinstance(value, str) and re.fullmatch(pattern, value) is not None, "invalid report identity")
    return value


def identity_tree(rows):
    require(isinstance(rows, list) and 0 < len(rows) <= 128, "invalid dataset tree")
    result = []
    for row in rows:
        result.append({
            "dataset": token(row["dataset"], r"[A-Za-z0-9_.:/-]{1,255}"),
            "guid": token(row["guid"], r"[1-9][0-9]*"),
            "mountpoint": token(row["mountpoint"], r"/[A-Za-z0-9_./-]*"),
        })
    require(len({row["dataset"] for row in result}) == len(result), "duplicate dataset identity")
    return result


def project(raw, transaction, release, hostname):
    """Project known fields; no arbitrary command output, exception or environment."""
    require(isinstance(raw, str) and len(raw.encode("utf-8")) <= 262144, "report exceeds size bound")
    data = json.loads(raw)
    require(isinstance(data, dict), "report must be an object")
    require(type(data.get("schema")) is int and data["schema"] in (1, 2), "unsupported CLI report schema")
    require(data.get("kind") == "reset_transaction_report", "not a CLI transaction report")
    require(data.get("id") == token(transaction, ID), "transaction mismatch")
    require(data.get("release") == token(release, "sha256:" + DIGEST), "release mismatch")
    host = data["host"]
    require(isinstance(host, dict), "invalid host object")
    require(host.get("hostname") == token(hostname, r"[A-Za-z0-9][A-Za-z0-9_.-]{0,252}"), "host mismatch")
    state = data["state"]
    require(state in ("pending", "stopped", "prepared", "accepted", "finalizing", "finalized"), "invalid state")
    lifecycle = state in ("accepted", "finalizing", "finalized")
    require((data["schema"] == 2) == lifecycle, "schema and lifecycle disagree")
    prepared = state in ("prepared", "accepted", "finalizing", "finalized")
    require(data.get("success") is prepared and data.get("accepted") is lifecycle and
            data.get("finalized") is (state == "finalized") and data.get("reboot_requested") is False,
            "inconsistent outcome flags")
    rows = data["phases"]
    require(isinstance(rows, list) and len(rows) <= len(PHASES), "invalid phase count")
    phases = []
    for index, row in enumerate(rows):
        require(row["phase"] == PHASES[index], "invalid phase order")
        require(row["state"] in ("started", "failed", "complete"), "invalid phase state")
        require(index == len(rows) - 1 or row["state"] == "complete", "incomplete earlier phase")
        require(type(row["attempt"]) is int and row["attempt"] > 0, "invalid attempt")
        require(row["boot_id"] == host["boot_id"], "phase boot mismatch")
        phase = {key: row[key] for key in ("phase", "state", "attempt", "boot_id")}
        phase["started_at"] = token(row["started_at"], r"[0-9T:.+Z-]{20,40}")
        if row["state"] != "started":
            phase["finished_at"] = token(row["finished_at"], r"[0-9T:.+Z-]{20,40}")
            native_exit = row["native_exit"]
            require(native_exit is None or type(native_exit) is int and 0 <= native_exit <= 255, "invalid native exit")
            phase["native_exit"] = native_exit
            commands = row["commands"]
            require(isinstance(commands, list) and len(commands) <= 128, "invalid command outcomes")
            phase["commands"] = []
            for command in commands:
                exit_code = command["native_exit"]
                require(exit_code is None or type(exit_code) is int and 0 <= exit_code <= 255, "invalid command exit")
                require(type(command["success"]) is bool, "invalid command result")
                require(command["operation"] in ("mountpoint", "root", "source", "modules", "puppet", "kexec"),
                        "unsupported native operation")
                require(row["state"] != "complete" or command["success"], "failed command in completed phase")
                phase["commands"].append({
                    "operation": token(command["operation"], r"[A-Za-z0-9_. -]{1,128}"),
                    "native_exit": exit_code, "success": command["success"],
                })
        phases.append(phase)
    require(not prepared or len(phases) == len(PHASES) and all(row["state"] == "complete" for row in phases),
            "incomplete prepared report")
    host_result = {"hostname": hostname, "boot_id": token(host["boot_id"], r"[0-9a-f-]{36}"),
                   "pool_guid": token(host["pool_guid"], r"[1-9][0-9]*")}
    for key in ("current", "target", "next_boot"):
        host_result[key] = token(host[key], r"[A-Za-z0-9_.:/-]{1,255}")
    host_result["current_tree"] = identity_tree(host["current_tree"])
    require(any(row["dataset"] == host_result["current"] and row["mountpoint"] == "/"
                for row in host_result["current_tree"]), "missing current root identity")
    require(all(row["dataset"] == host_result["current"] or row["dataset"].startswith(host_result["current"] + "/")
                for row in host_result["current_tree"]), "unrelated current tree member")
    shared = data["shared_state"]
    require("ROOT" not in shared["dataset"].split("/"), "shared state must be outside ROOT")
    source = data["source"]
    require(source["release"] == release, "source release mismatch")
    target_tree = None if data["target_tree"] is None else identity_tree(data["target_tree"])
    require(not prepared or target_tree is not None, "missing prepared target identity")
    if target_tree is not None:
        require(any(row["dataset"] == host_result["target"] and row["mountpoint"] == "/" for row in target_tree),
                "missing target root identity")
        require(all(row["dataset"] == host_result["target"] or row["dataset"].startswith(host_result["target"] + "/")
                    for row in target_tree), "unrelated target tree member")
    return {
        "schema": 1, "kind": "nest_update_retained_report", "cli_schema": data["schema"],
        "id": transaction, "release": release, "state": state, "host": host_result,
        "host_identity_sha256": token(data["host_identity_sha256"], DIGEST),
        "shared_state": {"dataset": token(shared["dataset"], r"[A-Za-z0-9_.:/-]{1,255}"),
                         "guid": token(shared["guid"], r"[1-9][0-9]*"),
                         "pool_guid": token(shared["pool_guid"], r"[1-9][0-9]*")},
        "source": {"path": token(source["path"], r"/[A-Za-z0-9_./-]+"),
                   "dataset": token(source["dataset"], r"[A-Za-z0-9_.:/-]{1,255}"),
                   "guid": token(source["guid"], r"[1-9][0-9]*"),
                   "creation_txg": token(source["creation_txg"], r"[1-9][0-9]*"), "release": release},
        "policy": {key: token(data["policy"][key], DIGEST) for key in ("filter_sha256", "cli_sha256")},
        "target_tree": target_tree, "phases": phases,
        "prepared": prepared, "cli_accepted": lifecycle, "cli_finalized": state == "finalized",
        "acceptance_independently_verified": False,
        "transport_sha256": hashlib.sha256(raw.encode("utf-8")).hexdigest(),
    }


def output_directory(directory):
    # An existing canonical directory is deliberate: never silently create an
    # unmounted/remote destination or hide a misspelled supervisor path.
    directory = Path(directory)
    require(directory.is_absolute() and str(directory.resolve(strict=True)) == str(directory),
            "output directory must already exist and be canonical")
    require(directory.is_dir() and not directory.is_symlink(), "invalid output directory")
    return directory


def publish_document(report, directory, prefix):
    directory = output_directory(directory)
    token(prefix, r"[A-Za-z0-9][A-Za-z0-9_.-]{0,400}")
    payload = (json.dumps(report, sort_keys=True, indent=2) + "\n").encode("utf-8")
    digest = hashlib.sha256(payload).hexdigest()
    # Content-addressed versions retain pending, failed and completed reports;
    # later observations never overwrite an earlier phase's only receipt.
    target = directory / (prefix + "-" + digest + ".json")
    fd, name = tempfile.mkstemp(prefix=".nest-update-report-", dir=directory)
    temporary = Path(name)
    try:
        os.fchmod(fd, 0o644)  # Only the sanitized allowlisted projection is public.
        with os.fdopen(fd, "wb") as output:
            output.write(payload)
            output.flush()
            os.fsync(output.fileno())
        try:
            os.link(temporary, target)
        except FileExistsError:
            require(target.is_file() and not target.is_symlink() and target.read_bytes() == payload,
                    "existing report does not match")
        directory_fd = os.open(directory, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
        require(not target.is_symlink() and target.read_bytes() == payload, "retained report readback mismatch")
        require(json.loads(target.read_text(encoding="utf-8")) == report, "retained report parse mismatch")
        return {"path": str(target), "sha256": digest, "bytes": len(payload), "readback_verified": True}
    finally:
        temporary.unlink(missing_ok=True)


def publish(report, directory):
    receipt = publish_document(report, directory, report["host"]["hostname"] + "-" + report["id"])
    return dict(receipt, id=report["id"], release=report["release"], hostname=report["host"]["hostname"],
                phase_count=len(report["phases"]), state=report["state"],
                cli_accepted=report["cli_accepted"], cli_finalized=report["cli_finalized"])


def main():
    try:
        arguments = json.load(sys.stdin)
        report = project(arguments["report"], arguments["transaction"], arguments["release"], arguments["hostname"])
        print(json.dumps(publish(report, arguments["output_dir"])))
    except (KeyError, TypeError, ValueError, OSError):
        # Do not print raw payloads, paths embedded in exceptions, or private host errors.
        print(json.dumps({"_error": {"kind": "nest/update-report", "msg": "Update report validation or durable publication failed"}}))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
