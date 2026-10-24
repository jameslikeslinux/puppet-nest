#!/usr/bin/env python3
"""Read bounded boot/kernel/ZFS observations; never accept or mutate an update."""

import json
import os
from pathlib import Path
import re
import socket
import subprocess
import sys
import time
from typing import Any


BOOT = r"[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}"
DATASET = r"[A-Za-z][A-Za-z0-9_.-]*(?:/[A-Za-z0-9_.:-]+)*/ROOT/[AB]"
GUID = r"[1-9][0-9]{0,19}"
ENV = {"PATH": "/usr/sbin:/usr/bin:/sbin:/bin", "LC_ALL": "C"}


class Unavailable(Exception):
    """The bounded observation did not establish the requested fact."""


def require(condition, reason):
    if not condition:
        raise Unavailable(reason)


def token(value, pattern):
    require(isinstance(value, str) and re.fullmatch(pattern, value) is not None, "invalid_expectations")
    return value


def expectations(value: Any):
    fields = {"hostname", "kernel", "previous_boot_id", "current", "current_guid", "var_guid", "pool_guid"}
    require(type(value) is dict and set(value) == fields, "invalid_expectations")
    token(value["hostname"], r"[A-Za-z0-9][A-Za-z0-9_.-]{0,252}")
    token(value["kernel"], r"[A-Za-z0-9][A-Za-z0-9_.+-]{0,127}")
    token(value["previous_boot_id"], BOOT)
    token(value["current"], DATASET)
    require(value["current"].split("/").count("ROOT") == 1, "invalid_expectations")
    for key in ("current_guid", "var_guid", "pool_guid"):
        token(value[key], GUID)
    require(value["current_guid"] != value["var_guid"], "invalid_expectations")
    return value


class Commands:
    def __init__(self):
        self.deadline = time.monotonic() + 30

    def __call__(self, argv):
        remaining = self.deadline - time.monotonic()
        require(remaining > 0, "collection_deadline")
        try:
            result = subprocess.run(argv, stdin=subprocess.DEVNULL, capture_output=True, env=ENV,
                                    timeout=min(5, remaining), check=False)
            require(result.returncode == 0, "command_failed")
            require(len(result.stdout) <= 1024 * 1024, "command_output_limit")
            return result.stdout.decode("utf-8")
        except (OSError, subprocess.TimeoutExpired, UnicodeError) as error:
            raise Unavailable("command_unavailable") from error


def boot_id():
    value = Path("/proc/sys/kernel/random/boot_id").read_text().strip()
    require(re.fullmatch(BOOT, value) is not None, "invalid_boot_id")
    return value


def mount_rows():
    # Kernel mountinfo retains shadowed/stacked mounts, not only the visible top.
    raw = Path("/proc/self/mountinfo").read_text()
    require(len(raw) <= 1024 * 1024, "mount_inventory_limit")
    return raw


def topology(raw, expected):
    lines = raw.splitlines()
    require(0 < len(lines) <= 16384, "mount_inventory_limit")
    selected = {"/": [], "/var": []}
    private_var = {}
    for line in lines:
        parts = line.split(" - ")
        require(len(parts) == 2, "invalid_mount_inventory")
        left, right = parts[0].split(), parts[1].split()
        require(len(left) >= 6 and len(right) == 3, "invalid_mount_inventory")
        if left[4].startswith("/var/") and right[0] == "zfs" and "ROOT" in right[1].split("/"):
            require(left[4] not in private_var and left[3] == "/"
                    and right[1] == expected["current"] + left[4]
                    and "rw" in left[5].split(",") and "rw" in right[2].split(","),
                    "wrong_private_var_mount")
            private_var[left[4]] = right[1]
        if left[4] in selected:
            selected[left[4]].append((left[3], right[0], right[1], left[5].split(","), right[2].split(",")))
    result = {}
    for path, dataset in (("/", expected["current"]), ("/var", expected["current"] + "/var")):
        rows = selected[path]
        require(len(rows) == 1, "missing_or_stacked_mount")
        root, filesystem, source, options, super_options = rows[0]
        require(root == "/" and filesystem == "zfs" and source == dataset
                and "rw" in options and "ro" not in options and "rw" in super_options
                and "ro" not in super_options, "wrong_or_read_only_mount")
        result[path] = source
    result.update(private_var)
    return result


def storage(run, expected):
    pool = expected["current"].split("/")[0]
    rows = [line.split("\t") for line in run(["zpool", "list", "-H", "-p", "-o", "name,guid,health"]).splitlines()]
    require(0 < len(rows) <= 128 and all(len(row) == 3 for row in rows), "invalid_pool_inventory")
    require(len({row[0] for row in rows}) == len(rows), "invalid_pool_inventory")
    for name, guid, health in rows:
        require(re.fullmatch(r"[A-Za-z][A-Za-z0-9_.-]{0,254}", name) is not None
                and re.fullmatch(GUID, guid) is not None, "invalid_pool_inventory")
        require(health == "ONLINE", "pool_not_online")
    require([row[1] for row in rows if row[0] == pool] == [expected["pool_guid"]], "root_pool_identity_mismatch")
    current = expected["current"]
    require(run(["zpool", "get", "-H", "-o", "value", "bootfs", pool]).strip() == current,
            "next_boot_mismatch")
    properties = run(["zfs", "get", "-H", "-p", "-o", "name,property,value", "guid,mounted", current, current + "/var"])
    found = {}
    for line in properties.splitlines():
        row = line.split("\t")
        require(len(row) == 3 and (row[0], row[1]) not in found, "invalid_dataset_inventory")
        found[(row[0], row[1])] = row[2]
    wanted = {(current, "guid"): expected["current_guid"], (current, "mounted"): "yes",
              (current + "/var", "guid"): expected["var_guid"], (current + "/var", "mounted"): "yes"}
    require(found == wanted, "dataset_identity_mismatch")
    return {"pool_guid": expected["pool_guid"], "current_guid": expected["current_guid"],
            "var_guid": expected["var_guid"], "current": current, "next_boot": current,
            "online_pools": {row[0]: row[1] for row in sorted(rows)}}


def collect(expected, run, mounts=mount_rows, boot=boot_id, hostname=socket.gethostname, kernel=lambda: os.uname().release):
    expected = expectations(expected)
    before = boot()
    token(before, BOOT)
    observed_host, observed_kernel = hostname(), kernel()
    token(observed_host, r"[A-Za-z0-9][A-Za-z0-9_.-]{0,252}")
    token(observed_kernel, r"[A-Za-z0-9][A-Za-z0-9_.+-]{0,127}")
    checks: dict[str, Any] = {
        "hostname": {"result": "pass" if observed_host == expected["hostname"] else "fail"},
        "kernel": {"result": "pass" if observed_kernel == expected["kernel"] else "fail"},
        "reboot": {"result": "pass" if before != expected["previous_boot_id"] else "fail"},
    }
    observers = (("mounts", lambda: topology(mounts(), expected)),
                 ("storage", lambda: storage(run, expected)))
    for name, observe in observers:
        try:
            first = observe()
            checks[name] = {"result": "pass", "observation": first}
        except Unavailable as error:
            checks[name] = {"result": "unavailable", "reason": str(error)}
    # Recheck both after the complete first acquisition, not just adjacent reads.
    for name, observe in observers:
        if checks[name]["result"] == "pass":
            try:
                require(observe() == checks[name]["observation"], "observation_changed")
            except Unavailable as error:
                checks[name] = {"result": "unavailable", "reason": str(error)}
    require(boot() == before and hostname() == observed_host and kernel() == observed_kernel,
            "boot_identity_changed_during_collection")
    return {"schema": 1, "kind": "nest_update_boot_health", "hostname": observed_host,
            "boot_id": before, "kernel": observed_kernel, "checks": checks,
            "result": "pass" if all(row["result"] == "pass" for row in checks.values()) else "fail",
            "acceptance_recorded": False}


def main():
    try:
        raw = sys.stdin.read(16385)
        require(len(raw.encode("utf-8")) <= 16384, "invalid_parameters")
        params: Any = json.loads(raw)
        require(type(params) is dict and "expectations" in params
                and all(key == "expectations" or key.startswith("_") for key in params), "invalid_parameters")
        require(os.geteuid() == 0, "root_required")
        result = collect(params["expectations"], Commands())
        print(json.dumps(result, sort_keys=True))
        return 0
    except (Unavailable, OSError, ValueError, TypeError, KeyError, RecursionError):
        print(json.dumps({"_error": {"kind": "nest/update-boot-health-unavailable",
                                     "msg": "Bound boot observation unavailable; no acceptance recorded"}}))
        return 1


if __name__ == "__main__":
    sys.exit(main())
