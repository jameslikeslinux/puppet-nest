#!/usr/bin/env python3
"""Retain invocation-bound catalog outcomes on the existing Bolt supervisor."""

import datetime
import hashlib
import json

import sys
from typing import Any

sys.dont_write_bytecode = True
from retain_update_report import DIGEST, ID, output_directory, publish_document, require, token

UUID = r"[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}"
NAME = r"[A-Za-z0-9][A-Za-z0-9_.-]{0,252}"
FIELDS = {"host", "environment", "configuration_version", "transaction_uuid", "catalog_uuid", "time",
          "status", "noop", "cached_catalog_status", "transaction_completed", "report_sha256"}


def unique(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "duplicate field")
        result[key] = value
    return result


def expectations(value: Any):
    require(type(value) is dict and set(value) == {"hostname", "certname", "boot_id", "configuration_version"},
            "invalid catalog expectations")
    for key in ("hostname", "certname"):
        token(value[key], NAME)
    token(value["boot_id"], UUID)
    token(value["configuration_version"], r"[0-9a-f]{40}")
    return value


def invocation(value: Any, expected: Any):
    require(type(value) is dict and type(value.get("report_bound")) is bool, "invalid invocation")
    code = value.get("native_exit")
    require(code is None or type(code) is int and 0 <= code <= 255, "invalid native exit")
    require(set(value) == ({"native_exit", "report_bound", "report"} if value["report_bound"]
                           else {"native_exit", "report_bound"}), "invalid invocation fields")
    if value["report_bound"]:
        require(code in (0, 2), "failed bound invocation")
        report: Any = value["report"]
        require(type(report) is dict and set(report) == FIELDS, "invalid native report fields")
        require(report["host"] == expected["certname"] and report["environment"] == "main"
                and report["configuration_version"] == expected["configuration_version"], "report identity mismatch")
        for key in ("transaction_uuid", "catalog_uuid"):
            token(report[key], UUID)
        token(report["report_sha256"], DIGEST)
        require(report["status"] == ("unchanged" if code == 0 else "changed")
                and report["noop"] is False and report["transaction_completed"] is True
                and report["cached_catalog_status"] == "not_used", "invalid native report outcome")
        token(report["time"], r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]{1,9})?(?:Z|[+-][0-9]{2}:[0-9]{2})")
        datetime.datetime.fromisoformat(report["time"].replace("Z", "+00:00"))
    return value


def project(raw, expected, transaction, release):
    require(type(raw) is str and len(raw.encode("utf-8")) <= 65536, "catalog transport limit")
    expected = expectations(expected)
    token(transaction, ID)
    token(release, "sha256:" + DIGEST)
    data: Any = json.loads(raw, object_pairs_hook=unique)
    base = {"schema", "kind", "result", "hostname", "boot_id", "configuration_version", "repeat_attempted",
            "converged", "served_source_verified", "acceptance_recorded", "main"}
    require(type(data) is dict and base <= set(data) <= base | {"repeat", "identity_binding_failed"},
            "invalid catalog fields")
    require(type(data["schema"]) is int and data["schema"] == 1 and data["kind"] == "nest_update_catalog_bound",
            "invalid catalog kind")
    require(data["hostname"] == expected["hostname"] and data["boot_id"] == expected["boot_id"]
            and data["configuration_version"] == expected["configuration_version"], "catalog binding mismatch")
    require(data["served_source_verified"] is False and data["acceptance_recorded"] is False,
            "unsupported acceptance assertion")
    require(type(data["repeat_attempted"]) is bool and type(data["converged"]) is bool, "invalid catalog flags")
    require("identity_binding_failed" not in data or data["identity_binding_failed"] is True, "invalid identity failure")
    first = invocation(data["main"], expected)
    require(("repeat" in data) == data["repeat_attempted"], "missing or unrequested repeat")
    converged = False
    if data["repeat_attempted"]:
        require(first["report_bound"], "repeat after unbound first apply")
        second = invocation(data["repeat"], expected)
        distinct = not second["report_bound"] or first["report"]["transaction_uuid"] != second["report"]["transaction_uuid"]
        require(distinct or data.get("identity_binding_failed") is True, "duplicate native transaction")
        converged = second["report_bound"] and second["native_exit"] == 0 and distinct
    converged = converged and data.get("identity_binding_failed") is not True
    require(data["converged"] is converged and data["result"] == ("pass" if converged else "fail"),
            "inconsistent catalog outcome")
    return {"schema": 1, "kind": "nest_update_retained_catalog", "transaction": transaction, "release": release,
            "expectations": expected, "catalog": data, "release_binding_verified": False,
            "served_source_verified": False, "acceptance_recorded": False,
            "transport_sha256": hashlib.sha256(raw.encode("utf-8")).hexdigest()}


def main():
    try:
        raw = sys.stdin.read(131073)
        require(len(raw.encode("utf-8")) <= 131072, "parameter limit")
        params: Any = json.loads(raw, object_pairs_hook=unique)
        required = {"action", "expectations", "transaction", "release", "output_dir"}
        require(type(params) is dict and required <= set(params)
                and all(key in required | {"report"} or key.startswith("_") for key in params), "invalid parameters")
        require(params["action"] in ("check", "retain"), "invalid action")
        expected = expectations(params["expectations"])
        token(params["transaction"], ID)
        token(params["release"], "sha256:" + DIGEST)
        directory = output_directory(params["output_dir"])
        if params["action"] == "check":
            require("report" not in params, "report on preflight")
            # Read-only path validation is not a writeability or future capacity guarantee.
            receipt = {"schema": 1, "kind": "nest_update_catalog_retention_check", "path_checked": True,
                       "acceptance_recorded": False}
        else:
            require(params.get("_noop") is not True, "retention is not noop")
            document = project(params["report"], expected, params["transaction"], params["release"])
            receipt = publish_document(document, directory, "catalog-" + params["transaction"])
            receipt.update(transaction=params["transaction"], release=params["release"], hostname=expected["hostname"],
                           result=document["catalog"]["result"], acceptance_recorded=False)
        print(json.dumps(receipt, sort_keys=True))
        return 0
    except (KeyError, TypeError, ValueError, OSError, RecursionError):
        print(json.dumps({"_error": {"kind": "nest/update-catalog-retention",
                                     "msg": "Catalog retention failed; inspect any prior apply before replay; no acceptance recorded"}}))
        return 1


if __name__ == "__main__":
    sys.exit(main())
