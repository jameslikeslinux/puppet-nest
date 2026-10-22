#!/usr/bin/env python3
"""Bounded read-only system and actual user-manager observations for updates."""

import json
import os
from pathlib import Path
import pwd
import re
import socket
import stat
import subprocess
import sys
import time


LIMIT = 128
UNIT = re.compile(r"[A-Za-z0-9_.@:\\-]{1,256}\Z")
USER_UNIT = re.compile(r"user@([0-9]+)\.service\Z")
BOOT = re.compile(r"[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\Z")
ENV = {"PATH": "/usr/sbin:/usr/bin:/sbin:/bin", "LC_ALL": "C", "SYSTEMD_COLORS": "0"}


class Unavailable(Exception):
    """A bounded observation could not establish an available complete inventory."""


class Commands:
    def __init__(self):
        self.deadline = time.monotonic() + 60

    def __call__(self, argv):
        remaining = self.deadline - time.monotonic()
        if remaining <= 0:
            raise Unavailable("collection_deadline")
        try:
            result = subprocess.run(argv, stdin=subprocess.DEVNULL, capture_output=True,
                                    env=ENV, timeout=min(5, remaining), check=False)
        except (OSError, subprocess.TimeoutExpired) as error:
            raise Unavailable("command_unavailable") from error
        if result.returncode != 0:
            raise Unavailable("command_failed")
        if len(result.stdout) > 1024 * 1024:
            raise Unavailable("command_output_limit")
        try:
            return result.stdout.decode("utf-8")
        except UnicodeError as error:
            raise Unavailable("command_encoding") from error


def units(run, prefix, failed=False):
    argv = prefix + ["list-units", "--all", "--no-pager", "--plain", "--output=json"]
    argv += ["--state=failed"] if failed else ["user@*.service"]
    try:
        rows = json.loads(run(argv))
    except (ValueError, TypeError) as error:
        raise Unavailable("invalid_unit_inventory") from error
    if not isinstance(rows, list) or len(rows) > LIMIT:
        raise Unavailable("unit_inventory_limit")
    found = {}
    for row in rows:
        if not isinstance(row, dict):
            raise Unavailable("invalid_unit_row")
        unit = row.get("unit")
        active, sub = row.get("active"), row.get("sub")
        if (not isinstance(unit, str) or not UNIT.fullmatch(unit) or unit in found
                or row.get("load") != "loaded" or not isinstance(active, str)
                or not isinstance(sub, str)):
            raise Unavailable("invalid_unit_row")
        if failed and active != "failed":
            raise Unavailable("invalid_failed_inventory")
        found[unit] = {"identity": unit, "active": active, "sub": sub}
    return sorted(found.values(), key=lambda row: row["identity"])


def manager_processes(proc=Path("/proc")):
    """Cross-check user@ units against actual systemd --user processes, not sessions."""
    found = {}
    try:
        entries = list(proc.iterdir())
        if len(entries) > 65536:
            raise Unavailable("process_inventory_limit")
        for path in entries:
            if not path.name.isdecimal():
                continue
            try:
                if (path / "comm").read_text().strip() != "systemd":
                    continue
                args = (path / "cmdline").read_bytes().split(b"\0")
                if b"--user" not in args:
                    continue
                uid = path.stat().st_uid
                found.setdefault(uid, []).append(int(path.name))
            except FileNotFoundError:
                # A process which exits during enumeration is checked by the repeat inventory.
                continue
    except OSError as error:
        raise Unavailable("process_inventory_unavailable") from error
    if len(found) > LIMIT or any(len(pids) != 1 for pids in found.values()):
        raise Unavailable("ambiguous_user_process_inventory")
    return {uid: pids[0] for uid, pids in found.items()}


def active_managers(rows):
    found = {}
    for row in rows:
        match = USER_UNIT.fullmatch(row["identity"])
        if not match:
            raise Unavailable("invalid_user_manager_unit")
        uid = int(match[1])
        if row["active"] == "inactive" and row["sub"] == "dead":
            continue
        if row["active"] != "active" or row["sub"] != "running" or uid in found:
            raise Unavailable("user_manager_not_running")
        found[uid] = row["identity"]
    return found


def user_prefix(uid):
    runtime = Path("/run/user") / str(uid)
    try:
        directory = runtime.lstat()
        bus = (runtime / "bus").lstat()
        account = pwd.getpwuid(uid)
    except (OSError, KeyError) as error:
        raise Unavailable("user_bus_unavailable") from error
    if (not stat.S_ISDIR(directory.st_mode) or directory.st_uid != uid
            or directory.st_mode & 0o022 or not stat.S_ISSOCK(bus.st_mode) or bus.st_uid != uid):
        raise Unavailable("unsafe_user_bus")
    return ["runuser", "-u", account.pw_name, "--", "env", "-i", "PATH=" + ENV["PATH"],
            "LC_ALL=C", "XDG_RUNTIME_DIR=" + str(runtime),
            "DBUS_SESSION_BUS_ADDRESS=unix:path=" + str(runtime / "bus"), "systemctl", "--user"]


def boot_id():
    value = Path("/proc/sys/kernel/random/boot_id").read_text().strip()
    if not BOOT.fullmatch(value):
        raise Unavailable("invalid_boot_id")
    return value


def collect(run, processes=manager_processes, prefix=user_prefix, boot=boot_id):
    observed_boot = boot()
    result = {"schema": 1, "kind": "nest_update_manager_health", "hostname": socket.gethostname(),
              "boot_id": observed_boot, "system_failures": {"availability": "unavailable", "inventory_complete": False},
              "user_managers": {"availability": "unavailable", "inventory_complete": False, "managers": []},
              "acceptance_recorded": False}
    try:
        failed = units(run, ["systemctl"], failed=True)
        result["system_failures"] = {"availability": "available", "inventory_complete": True,
                                     "result": "fail" if failed else "pass", "failures": failed}
    except Unavailable as error:
        result["system_failures"]["reason"] = str(error)
    users = result["user_managers"]
    try:
        before = active_managers(units(run, ["systemctl"]))
        pids = processes()
        if set(before) != set(pids):
            raise Unavailable("unit_process_inventory_mismatch")
        for uid in sorted(before):
            manager = {"identity": before[uid], "uid": uid, "pid": pids[uid],
                       "availability": "unavailable", "inventory_complete": False}
            users["managers"].append(manager)
            try:
                failed = units(run, prefix(uid), failed=True)
                manager.update(availability="available", inventory_complete=True,
                               result="fail" if failed else "pass", failures=failed)
            except Unavailable as error:
                manager["reason"] = str(error)
        if before != active_managers(units(run, ["systemctl"])) or pids != processes():
            raise Unavailable("user_manager_inventory_changed")
        complete = all(row["availability"] == "available" for row in users["managers"])
        users.update(availability="available" if complete else "unavailable", inventory_complete=complete)
        if complete:
            users["result"] = "pass" if all(row["result"] == "pass" for row in users["managers"]) else "fail"
    except Unavailable as error:
        users["reason"] = str(error)
    if boot() != observed_boot:
        raise Unavailable("boot_changed_during_collection")
    result["result"] = "pass" if all(result[key].get("result") == "pass" and result[key]["inventory_complete"]
                                                   for key in ("system_failures", "user_managers")) else "fail"
    return result


def main():
    try:
        params = json.loads(sys.stdin.read(4097))
        if not isinstance(params, dict) or any(not key.startswith("_") for key in params):
            raise Unavailable("unsupported_parameters")
        if os.geteuid() != 0:
            raise Unavailable("root_required_for_complete_inventory")
        result = collect(Commands())
        print(json.dumps(result, sort_keys=True))
        return 0
    except (Unavailable, OSError, ValueError, TypeError):
        # Never return raw command output, environment, private unit descriptions or exception text.
        print(json.dumps({"_error": {"kind": "nest/update-manager-health-unavailable",
                                     "msg": "Complete manager observation unavailable; no acceptance recorded"}}))
        return 1


if __name__ == "__main__":
    sys.exit(main())
