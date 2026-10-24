#!/usr/bin/env python3
"""Plan exact inventory-backed update waves; never execute or authorize them."""

import hashlib
import json
import re
import sys
from typing import Any

LIMIT = 262144
NAME = r"[a-z0-9][a-z0-9_.-]{0,127}"
SHA = r"[0-9a-f]{40}"
DIGEST = r"sha256:[0-9a-f]{64}"


def require(condition):
    if not condition:
        raise ValueError("Invalid update wave policy or inventory selection")


def fields(value, names):
    require(type(value) is dict and set(value) == set(names.split()))


def token(value: Any, pattern=NAME) -> str:
    if type(value) is not str:
        raise ValueError("Invalid update wave policy or inventory selection")
    require(re.fullmatch(pattern, value) is not None)
    return value


def names(value: Any, nonempty=True) -> list[str]:
    require(type(value) is list and (not nonempty or value) and len(value) <= 128)
    require(all(type(name) is str for name in value))
    require(len(value) == len(set(value)))
    return [token(name) for name in value]


def canonical(value):
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n").encode("ascii")


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result)
        result[key] = value
    return result


def plan(policy: Any, targets: Any):
    fields(policy, "schema kind release config_source max_parallel domains hosts excluded canaries")
    require(type(policy["schema"]) is int and policy["schema"] == 1)
    require(policy["kind"] == "nest_update_wave_policy")
    token(policy["release"], DIGEST)
    token(policy["config_source"], SHA)
    maximum = policy["max_parallel"]
    require(type(maximum) is int and 1 <= maximum <= 4)
    domains = names(policy["domains"])
    excluded = names(policy["excluded"], nonempty=False)
    canaries = names(policy["canaries"])
    selected = names(targets)
    require(not set(selected) & set(excluded))
    # Recovery consoles are never ordinary OS rollout targets, even if omitted
    # from a submitted exclusion list. The policy cannot override this floor.
    require(not any(name.split(".")[0].endswith("-console") for name in selected))
    hosts = policy["hosts"]
    require(type(hosts) is list and 0 < len(hosts) <= 128)
    indexed = {}
    used_domains = set()
    for host in hosts:
        fields(host, "name platform kernel domains")
        name = token(host["name"])
        token(host["platform"])
        # Reviewed exact release, including qualified exceptions, not a family
        # guess or arbitrary free-form shell text. This does not observe uname.
        token(host["kernel"], r"[A-Za-z0-9][A-Za-z0-9_.+-]{0,127}")
        memberships = names(host["domains"])
        require(set(memberships) <= set(domains))
        require(name not in indexed and name not in excluded and not name.split(".")[0].endswith("-console"))
        indexed[name] = host
        used_domains.update(memberships)
    require(used_domains == set(domains))
    # A partial target expression cannot silently remove a required canary or
    # turn an approved multi-host scope into a different run. Re-freeze policy.
    require(set(selected) == set(indexed) and set(canaries) <= set(indexed))
    require([row["name"] for row in hosts[:len(canaries)]] == canaries)

    waves = [[name] for name in canaries]
    remaining = [row["name"] for row in hosts if row["name"] not in canaries]
    while remaining:
        wave = []
        occupied = set()
        for name in remaining:
            memberships = set(indexed[name]["domains"])
            if len(wave) < maximum and not memberships & occupied:
                wave.append(name)
                occupied.update(memberships)
        require(wave)
        waves.append(wave)
        remaining = [name for name in remaining if name not in wave]
    return {
        "schema": 1, "kind": "nest_update_wave_plan", "result": "pass",
        "release": policy["release"], "config_source": policy["config_source"],
        "policy_sha256": hashlib.sha256(canonical(policy)).hexdigest(),
        "max_parallel": maximum, "host_count": len(hosts),
        "hosts": hosts, "excluded": excluded, "canaries": canaries, "waves": waves,
        "topology_verified": False, "release_binding_verified": False,
        "preparation_observed": False, "reboot_eligible": [],
        "execution_authorized": False, "acceptance_recorded": False,
    }


def main():
    try:
        raw = sys.stdin.buffer.read(LIMIT + 1)
        require(len(raw) <= LIMIT)
        params: Any = json.loads(raw, object_pairs_hook=unique_object)
        require(type(params) is dict and {"policy", "targets"} <= set(params)
                and all(key in {"policy", "targets"} or key.startswith("_") for key in params))
        print(json.dumps(plan(params["policy"], params["targets"]), sort_keys=True))
        return 0
    except (KeyError, TypeError, ValueError, UnicodeError, RecursionError):
        print(json.dumps({"_error": {"kind": "nest/update-wave-policy", "msg": "Invalid update wave policy or inventory selection; no host action performed"}}))
        return 1


if __name__ == "__main__":
    sys.exit(main())
