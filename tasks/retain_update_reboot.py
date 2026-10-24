#!/usr/bin/env python3
"""Retain native read-only reboot eligibility; never submit a reboot."""

import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from retain_update_report import (  # noqa: E402
    DIGEST, ID, output_directory, project, publish_document, require, token, unique,
)


def context(arguments):
    token(arguments["transaction"], ID)
    token(arguments["release"], "sha256:" + DIGEST)
    token(arguments["hostname"], r"[A-Za-z0-9][A-Za-z0-9_.-]{0,252}")
    output_directory(arguments["output_dir"])


def retain(arguments):
    raw = arguments["report"]
    report = project(raw, arguments["transaction"], arguments["release"], arguments["hostname"])
    data = json.loads(raw, object_pairs_hook=unique)
    require(data.get("read_only") is True and type(data.get("reboot_eligible")) is bool, "not a native reboot plan")
    reason = data.get("reboot_reason")
    require(reason in ("eligible", "already_requested", "already_booted") and
            data["reboot_eligible"] is (reason == "eligible"), "invalid eligibility outcome")
    observed = report.get("observation", {})
    if reason == "already_booted":
        require(report["prepared"] and observed.get("boot_changed") is True and
                observed.get("expected_target_booted") is True and observed.get("current") == report["host"]["target"] and
                observed.get("next_boot") == report["host"]["target"], "missing exact changed target boot")
    else:
        require(report["state"] == "prepared" and observed.get("boot_changed") is False and
                observed.get("expected_target_booted") is False and observed.get("current") == report["host"]["current"] and
                observed.get("next_boot") == report["host"]["target"], "missing exact prepared boot")
        require(("reboot" in report) == (reason == "already_requested"), "request receipt and eligibility disagree")
    # Native CLI owns locked storage/source/policy admission. This is retained
    # observation, not an independently verified lease or disruption permission.
    document = {
        "schema": 1, "kind": "nest_update_reboot_plan", "transaction": arguments["transaction"],
        "release": arguments["release"], "hostname": arguments["hostname"], "report": report,
        "read_only": True, "reboot_eligible": data["reboot_eligible"], "reboot_reason": reason,
        "execution_requested": False, "acceptance_recorded": False,
    }
    receipt = publish_document(document, arguments["output_dir"], "reboot-plan-" + arguments["transaction"])
    return dict(receipt, transaction=arguments["transaction"], release=arguments["release"], hostname=arguments["hostname"],
                read_only=True, reboot_eligible=data["reboot_eligible"], reboot_reason=reason,
                execution_requested=False, acceptance_recorded=False)


def main():
    try:
        arguments = json.load(sys.stdin, object_pairs_hook=unique)
        context(arguments)
        require(arguments["action"] in ("check", "retain"), "invalid action")
        result = {"destination_checked": True, "host_action_performed": False} if arguments["action"] == "check" else retain(arguments)
        print(json.dumps(result))
        return 0
    except (KeyError, TypeError, ValueError, OSError):
        print(json.dumps({"_error": {"kind": "nest/update-reboot-plan", "msg": "Native reboot plan binding or retention failed; no reboot submitted"}}))
        return 1


if __name__ == "__main__":
    sys.exit(main())
