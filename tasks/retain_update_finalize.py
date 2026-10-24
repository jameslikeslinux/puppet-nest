#!/usr/bin/env python3
"""Bind native A/B finalization to live status; never issue host commands."""

import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from retain_update_report import (  # noqa: E402
    DIGEST, ID, output_directory, project, publish_document, require, token,
)

SNAPSHOT_POLICY = "retain_origins_no_reclamation_claim"
BINDINGS = ("id", "release", "host", "host_identity_sha256", "shared_state", "source", "policy", "target_tree", "phases", "reboot_requested")


def unique(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "duplicate field")
        result[key] = value
    return result


def context(arguments):
    token(arguments["transaction"], ID)
    token(arguments["release"], "sha256:" + DIGEST)
    token(arguments["hostname"], r"[A-Za-z0-9][A-Za-z0-9_.-]{0,252}")
    output_directory(arguments["output_dir"])


def native(raw, arguments):
    # Reject contradictory duplicate keys before the shared projection parser.
    require(isinstance(raw, str) and len(raw.encode("utf-8")) <= 262144, "native report exceeds bound")
    data = json.loads(raw, object_pairs_hook=unique)
    document = project(raw, arguments["transaction"], arguments["release"], arguments["hostname"])
    require(document["cli_accepted"], "native acceptance required")
    # No production preparation currently creates an extra. Do not adopt user
    # extras or a future ownership shape through this deliberately narrow plan.
    require(data.get("owned_candidates") == [] and data.get("cleanup_receipts") == [], "only ordinary A/B supported")
    require(data.get("snapshot_policy") == SNAPSHOT_POLICY, "unsupported snapshot policy")
    acceptance = data["acceptance"]
    require(isinstance(acceptance, dict), "missing native acceptance")
    boot = token(acceptance["boot_id"], r"[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}")
    require(boot != document["host"]["boot_id"], "unchanged acceptance boot")
    document["accepted_boot_id"] = boot
    return document, data


def admission(raw, arguments):
    document, _data = native(raw, arguments)
    observed = document.get("observation", {})
    require(observed.get("boot_changed") is True and observed.get("expected_target_booted") is True and
            observed.get("cli_accepted_current_boot") is True and observed.get("boot_id") == document["accepted_boot_id"] and
            observed.get("current") == document["host"]["target"] and
            observed.get("next_boot") == document["host"]["target"], "live accepted target boot required")
    return document


def retain(arguments):
    before = admission(arguments["status"], arguments)
    action = arguments["action"]
    if action == "admit":
        report = before
    else:
        report, data = native(arguments["report"], arguments)
        require(all(report[key] == before[key] for key in BINDINGS) and report.get("reboot") == before.get("reboot") and
                report["accepted_boot_id"] == before["accepted_boot_id"], "finalization identity changed")
        if action == "preview":
            require(data.get("read_only") is True and data.get("cleanup") == "owned" and data.get("candidates") == [] and
                    report["state"] == before["state"], "invalid native preview")
        else:
            require(action == "complete" and report["cli_finalized"] and data.get("read_only", False) is False,
                    "native finalization incomplete")
    document = {
        "schema": 1, "kind": "nest_update_finalize", "action": action,
        "transaction": arguments["transaction"], "release": arguments["release"], "hostname": arguments["hostname"],
        "status": before, "report": report, "snapshot_policy": SNAPSHOT_POLICY,
        "owned_candidate_count": 0, "acceptance_independently_verified": False,
    }
    receipt = publish_document(document, arguments["output_dir"], "finalize-" + action + "-" + arguments["transaction"])
    return dict(receipt, transaction=arguments["transaction"], release=arguments["release"], hostname=arguments["hostname"],
                action=action, state=report["state"], cli_finalized=report["cli_finalized"],
                acceptance_independently_verified=False)


def main():
    try:
        arguments = json.load(sys.stdin, object_pairs_hook=unique)
        context(arguments)
        require(arguments["action"] in ("check", "admit", "preview", "complete"), "invalid action")
        result = {"destination_checked": True, "host_action_performed": False} if arguments["action"] == "check" else retain(arguments)
        print(json.dumps(result))
        return 0
    except (KeyError, TypeError, ValueError, OSError):
        print(json.dumps({"_error": {"kind": "nest/update-finalize", "msg": "Native finalization binding or retention failed; observe before any retry"}}))
        return 1


if __name__ == "__main__":
    sys.exit(main())
