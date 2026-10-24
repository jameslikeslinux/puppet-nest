#!/usr/bin/env python3
"""Retain sanitized postboot health observations, never transaction acceptance."""

import hashlib
import json

import sys
from typing import Any

sys.dont_write_bytecode = True
from retain_update_report import DIGEST, ID, output_directory, publish_document, require, token
import update_boot_health as boot
import update_network_health as network

HOST = r"[A-Za-z0-9][A-Za-z0-9_.-]{0,252}"
UNIT = r"[A-Za-z0-9_.@:\\-]{1,256}"


def unique(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "duplicate field")
        result[key] = value
    return result


def context(expected, endpoints, transaction, release):
    boot.expectations(expected)
    require(type(endpoints) is list, "invalid endpoints")
    if endpoints:
        network.policy(endpoints)
    token(transaction, ID)
    token(release, "sha256:" + DIGEST)


def verdict(value):
    require(value in ("pass", "fail"), "invalid outcome")
    return value


def reason(row, projected):
    if "reason" in row:
        # Producers emit fixed diagnostic codes, never exception or command text.
        projected["reason"] = token(row["reason"], r"[a-z][a-z0-9_]{0,95}")
    return projected


def identity(value, kind):
    require(type(value) is dict and type(value.get("schema")) is int and value["schema"] == 1
            and value.get("kind") == kind and value.get("acceptance_recorded") is False, "invalid health identity")
    return {"hostname": token(value["hostname"], HOST), "boot_id": token(value["boot_id"], boot.BOOT)}


def boot_summary(value: Any, expected: Any):
    result = identity(value, "nest_update_boot_health")
    result["kernel"] = token(value["kernel"], r"[A-Za-z0-9][A-Za-z0-9_.+-]{0,127}")
    checks = value["checks"]
    require(type(checks) is dict and set(checks) == {"hostname", "kernel", "reboot", "mounts", "storage"}, "missing boot checks")
    projected: dict[str, Any] = {}
    for name, row in checks.items():
        require(type(row) is dict and row.get("result") in ("pass", "fail", "unavailable"), "invalid boot check")
        projected[name] = reason(row, {"result": row["result"]})
    for name, matches in (("hostname", result["hostname"] == expected["hostname"]),
                          ("kernel", result["kernel"] == expected["kernel"]),
                          ("reboot", result["boot_id"] != expected["previous_boot_id"])):
        require(checks[name]["result"] == ("pass" if matches else "fail"), "inconsistent boot check")
    result.update(checks=projected, result=verdict(value["result"]))
    require((result["result"] == "pass") == all(row["result"] == "pass" for row in checks.values()), "inconsistent boot result")
    # The native collector owns mount/storage validation. Keep a digest of the
    # complete observation for bracket equality, without copying arbitrary paths.
    result["observation_sha256"] = hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    return result


def failures(rows: Any):
    require(type(rows) is list and len(rows) <= 128, "invalid failure inventory")
    projected = []
    for row in rows:
        require(type(row) is dict and row.get("active") == "failed", "invalid failed unit")
        projected.append({"identity": token(row["identity"], UNIT), "active": "failed",
                          "sub": token(row["sub"], r"[a-z][a-z0-9-]{0,63}")})
    require(len({row["identity"] for row in projected}) == len(projected), "duplicate failed unit")
    return projected


def inventory(row: Any):
    require(type(row) is dict and row.get("availability") in ("available", "unavailable")
            and type(row.get("inventory_complete")) is bool, "invalid inventory")
    complete = row["inventory_complete"]
    require(complete == (row["availability"] == "available"), "inconsistent availability")
    result = reason(row, {"availability": row["availability"], "inventory_complete": complete})
    for key in ("failures", "failures_after"):
        if key in row:
            result[key] = failures(row[key])
    if complete:
        require("failures" in result and row.get("result") == ("fail" if result["failures"] else "pass"), "inconsistent failure result")
    elif "result" in row:
        require(row["result"] == "fail", "unavailable inventory cannot pass")
    result["result"] = row.get("result", "fail")
    return result


def manager_summary(value: Any):
    result = identity(value, "nest_update_manager_health")
    result["system_failures"] = inventory(value["system_failures"])
    users = value["user_managers"]
    require(type(users) is dict and users.get("availability") in ("available", "unavailable")
            and type(users.get("inventory_complete")) is bool, "invalid manager inventory")
    rows = users["managers"]
    require(type(rows) is list and len(rows) <= 128, "invalid manager count")
    managers = []
    for row in rows:
        require(type(row) is dict and type(row.get("uid")) is int and 0 <= row["uid"] <= 4294967295
                and type(row.get("pid")) is int and row["pid"] > 0
                and row.get("identity") == "user@" + str(row["uid"]) + ".service", "invalid manager identity")
        managers.append(dict(inventory(row), identity=row["identity"], uid=row["uid"], pid=row["pid"]))
    require(len({row["uid"] for row in managers}) == len(managers)
            and len({row["pid"] for row in managers}) == len(managers), "duplicate manager")
    complete = users["inventory_complete"]
    require(complete == (users["availability"] == "available"), "inconsistent manager availability")
    require(not complete or all(row["inventory_complete"] for row in managers), "incomplete manager bus")
    healthy = complete and all(row["result"] == "pass" for row in managers)
    require(users.get("result", "fail") == ("pass" if healthy else "fail"), "inconsistent manager result")
    result["user_managers"] = reason(users, {"availability": users["availability"], "inventory_complete": complete,
                                              "result": "pass" if healthy else "fail", "managers": managers})
    healthy = healthy and result["system_failures"]["result"] == "pass"
    require(value.get("result") == ("pass" if healthy else "fail"), "inconsistent aggregate manager result")
    result["result"] = value["result"]
    return result


def network_summary(value: Any, endpoints: Any):
    result = identity(value, "nest_update_network_health")
    rows = value["endpoints"]
    require(type(rows) is list and len(rows) == len(endpoints), "incomplete endpoint observations")
    projected = []
    for row, expected in zip(rows, endpoints):
        require(type(row) is dict and row.get("hostname") == expected["hostname"]
                and row.get("availability") in ("available", "unavailable"), "endpoint mismatch")
        status = verdict(row["result"])
        if row["availability"] == "unavailable":
            require(status == "fail", "unavailable endpoint cannot pass")
        else:
            require(set(row["resolved_addresses"]) == set(expected["addresses"]), "resolution mismatch")
            https = row["https"]
            require(type(https["status"]) is int and 100 <= https["status"] <= 599
                    and https["system_trust_verified"] is True and https["remote_address"] in expected["addresses"], "invalid HTTPS observation")
            require((status == "pass") == (https["status"] == expected["status"]), "inconsistent HTTPS result")
        projected.append(reason(row, {"hostname": row["hostname"], "availability": row["availability"], "result": status}))
    require(value.get("result") == ("pass" if all(row["result"] == "pass" for row in projected) else "fail"), "inconsistent network result")
    return dict(result, endpoints=projected, result=value["result"])


def project(raw, expected, endpoints, transaction, release):
    context(expected, endpoints, transaction, release)
    require(type(raw) is str and len(raw.encode()) <= 262144, "health report limit")
    data: Any = json.loads(raw, object_pairs_hook=unique)
    fields = {"schema", "kind", "result", "observations_bound", "boot_before", "managers", "network", "network_requested", "boot_after", "acceptance_recorded"}
    require(type(data) is dict and set(data) == fields and type(data["schema"]) is int and data["schema"] == 1
            and data["kind"] == "nest_update_health" and data["acceptance_recorded"] is False, "invalid health report")
    before, after = [boot_summary(data[key], expected) for key in ("boot_before", "boot_after")]
    managers = manager_summary(data["managers"])
    require(type(data["network_requested"]) is bool and data["network_requested"] == bool(endpoints)
            and (data["network"] is not None) == bool(endpoints), "network scope mismatch")
    client = network_summary(data["network"], endpoints) if endpoints else None
    bound = before["hostname"] == expected["hostname"] and data["boot_before"] == data["boot_after"]
    bound = bound and all(row["hostname"] == before["hostname"] and row["boot_id"] == before["boot_id"]
                          for row in ([managers, client] if client else [managers]))
    require(type(data["observations_bound"]) is bool and data["observations_bound"] == bound, "inconsistent health binding")
    healthy = bound and all(row["result"] == "pass" for row in ([before, managers, client] if client else [before, managers]))
    require(data["result"] == ("pass" if healthy else "fail"), "inconsistent health outcome")
    return {"schema": 1, "kind": "nest_update_retained_health", "transaction": transaction, "release": release,
            "expectations": expected, "endpoints": endpoints, "result": data["result"], "observations_bound": bound,
            "boot_before": before, "managers": managers, "network": client, "boot_after": after,
            "acceptance_recorded": False, "preparation_verified": False,
            "transport_sha256": hashlib.sha256(raw.encode()).hexdigest()}


def main():
    try:
        raw = sys.stdin.read(524289)
        require(len(raw.encode()) <= 524288, "parameter limit")
        params: Any = json.loads(raw, object_pairs_hook=unique)
        required = {"action", "expectations", "endpoints", "transaction", "release", "output_dir"}
        require(type(params) is dict and required <= set(params)
                and all(key in required | {"report"} or key.startswith("_") for key in params), "invalid parameters")
        context(params["expectations"], params["endpoints"], params["transaction"], params["release"])
        directory = output_directory(params["output_dir"])
        if params["action"] == "check":
            require("report" not in params, "report on preflight")
            receipt = {"destination_checked": True, "acceptance_recorded": False}
        else:
            require(params["action"] == "retain" and params.get("_noop") is not True, "invalid retention action")
            document = project(params["report"], params["expectations"], params["endpoints"], params["transaction"], params["release"])
            receipt = publish_document(document, directory, "health-" + params["transaction"])
            receipt.update(transaction=params["transaction"], release=params["release"], result=document["result"],
                           observations_bound=document["observations_bound"], acceptance_recorded=False)
        print(json.dumps(receipt, sort_keys=True))
        return 0
    except (KeyError, TypeError, ValueError, OSError, RecursionError, boot.Unavailable, network.Unavailable):
        print(json.dumps({"_error": {"kind": "nest/update-health-retention",
                                     "msg": "Health validation or retention failed; no acceptance recorded"}}))
        return 1


if __name__ == "__main__":
    sys.exit(main())
