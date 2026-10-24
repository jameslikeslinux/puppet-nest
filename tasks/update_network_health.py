#!/usr/bin/env python3
"""Bounded client-route, system-resolution and HTTPS trust observations."""

import ipaddress
import json
from pathlib import Path
import re
import socket
import subprocess
import sys
import time


BOOT = re.compile(r"[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\Z")
HOST = re.compile(r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+\Z")
ENV = {"PATH": "/usr/sbin:/usr/bin:/sbin:/bin", "LC_ALL": "C"}


class Unavailable(Exception):
    """A complete bounded observation could not be obtained."""


class Commands:
    def __init__(self):
        self.deadline = time.monotonic() + 30

    def __call__(self, argv):
        remaining = self.deadline - time.monotonic()
        if remaining <= 0:
            raise Unavailable("collection_deadline")
        try:
            result = subprocess.run(argv, stdin=subprocess.DEVNULL, capture_output=True,
                                    env=ENV, timeout=min(6, remaining), check=False)
        except (OSError, subprocess.TimeoutExpired) as error:
            raise Unavailable("command_unavailable") from error
        if result.returncode != 0:
            raise Unavailable("command_failed")
        if len(result.stdout) > 65536:
            raise Unavailable("command_output_limit")
        try:
            return result.stdout.decode("utf-8")
        except UnicodeError as error:
            raise Unavailable("command_encoding") from error


def require(condition, reason):
    if not condition:
        raise Unavailable(reason)


def address(value):
    require(isinstance(value, str), "invalid_address")
    try:
        parsed = ipaddress.ip_address(value)
    except ValueError as error:
        raise Unavailable("invalid_address") from error
    require(str(parsed) == value and not parsed.is_unspecified and not parsed.is_multicast
            and not parsed.is_loopback and not parsed.is_link_local, "unsupported_address")
    return value


def policy(rows):
    require(isinstance(rows, list) and 1 <= len(rows) <= 4, "invalid_endpoint_count")
    names = set()
    for row in rows:
        require(isinstance(row, dict) and set(row) == {"hostname", "addresses", "path", "status"},
                "invalid_endpoint_fields")
        host = row["hostname"]
        require(isinstance(host, str) and len(host) <= 253 and HOST.fullmatch(host) is not None
                and host not in names, "invalid_endpoint_hostname")
        try:
            ipaddress.ip_address(host)
        except ValueError:
            pass
        else:
            raise Unavailable("invalid_endpoint_hostname")
        names.add(host)
        ips = row["addresses"]
        require(isinstance(ips, list) and 1 <= len(ips) <= 8 and all(isinstance(ip, str) for ip in ips)
                and len(set(ips)) == len(ips), "invalid_endpoint_addresses")
        for ip in ips:
            address(ip)
        # No credentials, fragments, queries, ports, URL expansion or redirect policy.
        require(isinstance(row["path"], str) and re.fullmatch(r"/[A-Za-z0-9_./-]{0,255}", row["path"])
                and ".." not in row["path"].split("/"), "invalid_endpoint_path")
        require(type(row["status"]) is int and 200 <= row["status"] <= 299, "invalid_endpoint_status")
    return rows


def resolve(run, hostname):
    raw = run(["getent", "ahosts", hostname])
    found = set()
    for line in raw.splitlines():
        fields = line.split()
        require(2 <= len(fields) <= 3 and fields[1] in ("STREAM", "DGRAM", "RAW"), "invalid_resolution")
        found.add(address(fields[0]))
    require(0 < len(found) <= 8, "incomplete_resolution")
    return sorted(found)


def routes(run, ips):
    result = []
    for ip in ips:
        try:
            rows = json.loads(run(["ip", "-json", "route", "get", ip]))
        except (ValueError, TypeError) as error:
            raise Unavailable("invalid_route") from error
        require(isinstance(rows, list) and len(rows) == 1 and isinstance(rows[0], dict), "invalid_route")
        row = rows[0]
        require(row.get("type", "unicast") == "unicast" and row.get("dst") == ip
                and isinstance(row.get("dev"), str) and re.fullmatch(r"[A-Za-z0-9_.:-]{1,64}", row["dev"])
                and row["dev"] != "lo", "unsupported_route")
        source = address(row.get("prefsrc", row.get("src")))
        require(ipaddress.ip_address(source).version == ipaddress.ip_address(ip).version, "invalid_route_source")
        gateway = address(row["gateway"]) if "gateway" in row else None
        result.append({"destination": ip, "device": row["dev"], "source": source, "gateway": gateway})
    return result


def probe(run, endpoint, resolved):
    # -q is first: never load per-user curl configuration. Clear proxy/custom-CA
    # environment and use the host's ordinary system trust; do not follow redirects.
    raw = run(["curl", "-q", "--silent", "--noproxy", "*", "--proto", "=https",
               "--connect-timeout", "3", "--max-time", "5", "--max-redirs", "0",
               "--output", "/dev/null", "--write-out", "%{http_code} %{remote_ip} %{ssl_verify_result}",
               "https://" + endpoint["hostname"] + endpoint["path"]])
    fields = raw.split()
    require(len(fields) == 3 and re.fullmatch(r"[0-9]{3}", fields[0]) is not None
            and fields[2] == "0", "invalid_https_observation")
    remote = address(fields[1])
    require(remote in resolved, "https_destination_mismatch")
    return {"status": int(fields[0]), "remote_address": remote, "system_trust_verified": True}


def boot_id():
    value = Path("/proc/sys/kernel/random/boot_id").read_text().strip()
    require(BOOT.fullmatch(value) is not None, "invalid_boot_id")
    return value


def collect(endpoints, run, boot=boot_id, hostname=socket.gethostname):
    endpoints = policy(endpoints)
    observed_boot, observed_host = boot(), hostname()
    require(isinstance(observed_boot, str) and BOOT.fullmatch(observed_boot) is not None, "invalid_boot_id")
    result = {"schema": 1, "kind": "nest_update_network_health", "hostname": observed_host,
              "boot_id": observed_boot, "endpoints": [], "acceptance_recorded": False}
    for endpoint in endpoints:
        row = {"hostname": endpoint["hostname"], "availability": "unavailable", "result": "fail"}
        result["endpoints"].append(row)
        try:
            resolved = resolve(run, endpoint["hostname"])
            require(set(resolved) == set(endpoint["addresses"]), "resolution_policy_mismatch")
            before = routes(run, resolved)
            https = probe(run, endpoint, resolved)
            require(resolve(run, endpoint["hostname"]) == resolved and routes(run, resolved) == before,
                    "network_changed_during_collection")
            row.update(availability="available", resolved_addresses=resolved, routes=before, https=https,
                       result="pass" if https["status"] == endpoint["status"] else "fail")
        except Unavailable as error:
            row["reason"] = str(error)
    require(boot() == observed_boot and hostname() == observed_host, "host_changed_during_collection")
    result["result"] = "pass" if all(row["result"] == "pass" for row in result["endpoints"]) else "fail"
    return result


def main():
    try:
        raw = sys.stdin.read(16385)
        require(len(raw) <= 16384, "parameter_limit")
        params = json.loads(raw)
        require(isinstance(params, dict) and "endpoints" in params
                and all(key == "endpoints" or key.startswith("_") for key in params), "unsupported_parameters")
        print(json.dumps(collect(params["endpoints"], Commands()), sort_keys=True))
        return 0
    except (Unavailable, OSError, ValueError, TypeError):
        print(json.dumps({"_error": {"kind": "nest/update-network-health-unavailable",
                                     "msg": "Complete network observation unavailable; no acceptance recorded"}}))
        return 1


if __name__ == "__main__":
    sys.exit(main())
