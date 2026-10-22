#!/usr/bin/env python3
"""Read-only admission of existing private Stage 3 identity and output paths."""

import argparse
import os
from pathlib import Path
import pwd
import re
import stat
import sys


def require(value):
    if not value:
        raise ValueError("Stage 3 identity/path admission failed")


def trusted_owners():
    # Puppet owns its existing SSL material; root owns the outer identity tree.
    puppet = pwd.getpwnam("puppet")
    return {0, puppet.pw_uid}, {0, puppet.pw_gid}


def canonical(value):
    path = Path(value)
    require(path.is_absolute() and str(path) == value and ".." not in path.parts)
    # resolve(strict=False) also detects links in existing ancestors of an output
    # that has not been created. Never silently canonicalize a supplied identity.
    require(path.resolve() == path)
    return path


def safe_directory(path, owners, groups):
    info = path.lstat()
    require(stat.S_ISDIR(info.st_mode) and info.st_uid in owners)
    require(not info.st_mode & stat.S_IWOTH)
    require(not info.st_mode & stat.S_IWGRP or info.st_gid in groups)


def safe_file(path, owners, private=False):
    info = path.lstat()
    require(stat.S_ISREG(info.st_mode) and info.st_uid in owners)
    require(not info.st_mode & (stat.S_IWGRP | stat.S_IWOTH))
    require(not private or not info.st_mode & (stat.S_IRWXG | stat.S_IRWXO))
    require(0 < info.st_size <= 1024 * 1024)
    # Admission checks readability, without printing, hashing or parsing secrets.
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    try:
        require(os.fstat(descriptor) == info)
    finally:
        os.close(descriptor)


def walk_error(error):
    raise error


def check(identity_value, output_value, hostname):
    require(re.fullmatch(r"[a-z0-9][a-z0-9-]{0,62}", hostname) is not None)
    identity, output = canonical(identity_value), canonical(output_value)
    require(identity != output and identity not in output.parents and output not in identity.parents)
    owners, groups = trusted_owners()
    # The source's complete ancestry must be protected against untrusted path
    # replacement. An existing publication ancestor must be protected as well.
    for path in [identity, *identity.parents]:
        safe_directory(path, {0}, {0})
    for path in [output, *output.parents]:
        if path.exists():
            safe_directory(path, {0}, {0})
    machine = identity / "etc/machine-id"
    ssl = identity / "etc/puppetlabs/puppet/ssl"
    for path in [identity / "etc", identity / "etc/puppetlabs", identity / "etc/puppetlabs/puppet"]:
        safe_directory(path, {0}, {0})
    safe_file(machine, {0})
    machine_bytes = machine.read_bytes()
    require(re.fullmatch(rb"[0-9a-f]{32}\n?", machine_bytes) is not None)
    require(machine_bytes.strip() != b"0" * 32)
    # The entire recursively copied SSL source must be local regular material:
    # no links, devices, sockets or untrusted writers hidden in extra subtrees.
    safe_directory(ssl, owners, groups)
    for directory, directories, files in os.walk(ssl, followlinks=False, onerror=walk_error):
        for name in directories:
            safe_directory(Path(directory) / name, owners, groups)
        for name in files:
            path = Path(directory) / name
            safe_file(path, owners, private="private_keys" in path.relative_to(ssl).parts)
    for relative, private in [("certs/ca.pem", False), ("certs/" + hostname + ".pem", False),
                              ("private_keys/" + hostname + ".pem", True)]:
        safe_file(ssl / relative, owners, private)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("identity_root")
    parser.add_argument("publication_root")
    parser.add_argument("hostname")
    args = parser.parse_args()
    try:
        check(args.identity_root, args.publication_root, args.hostname)
        print("Stage 3 identity/path admission passed")
        return 0
    except (OSError, ValueError, KeyError, RuntimeError):
        # No filenames, certificate bytes, keys, machine identity or traceback.
        print("Stage 3 identity/path admission failed", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
