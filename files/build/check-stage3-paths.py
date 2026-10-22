#!/usr/bin/env python3
"""Read-only admission of existing private Stage 3 identity and output paths."""

import argparse
import fcntl
import hashlib
import os
from pathlib import Path
import pwd
import re
import stat
import subprocess
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


def read_material(path):
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    try:
        before = os.fstat(descriptor)
        require(stat.S_ISREG(before.st_mode) and 0 < before.st_size <= 1024 * 1024)
        with os.fdopen(descriptor, "rb", closefd=False) as source:
            value = source.read(1024 * 1024 + 1)
        after = os.fstat(descriptor)
        fields = ("st_dev", "st_ino", "st_size", "st_mode", "st_uid", "st_gid", "st_mtime_ns", "st_ctime_ns")
        require(len(value) == before.st_size and all(getattr(before, f) == getattr(after, f) for f in fields))
        return value
    finally:
        os.close(descriptor)


def openssl(arguments, payload, descriptors=()):
    # No inherited configuration, engines, shell, password prompt or diagnostics.
    result = subprocess.run(["/usr/bin/openssl", *arguments], input=payload,
                            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                            env={"PATH": "/usr/bin:/bin", "OPENSSL_CONF": "/dev/null"},
                            pass_fds=descriptors, timeout=15, check=False)
    require(result.returncode == 0)
    return result.stdout


def check_tls(ssl, hostname, ca_sha256):
    require(re.fullmatch(r"[0-9a-f]{64}", ca_sha256) is not None)
    ca = read_material(ssl / "certs/ca.pem")
    require(hashlib.sha256(ca).hexdigest() == ca_sha256)
    certificate = read_material(ssl / ("certs/" + hostname + ".pem"))
    key = read_material(ssl / ("private_keys/" + hostname + ".pem"))
    require(re.fullmatch(rb"-----BEGIN CERTIFICATE-----\s+[A-Za-z0-9+/=\r\n]+-----END CERTIFICATE-----\s*", certificate) is not None)
    require(re.fullmatch(rb"-----BEGIN (PRIVATE KEY|RSA PRIVATE KEY|EC PRIVATE KEY)-----\s+"
                         rb"[A-Za-z0-9+/=\r\n]+-----END \1-----\s*", key) is not None)
    # Compare public keys only in memory. Never emit even a private-key digest.
    public = openssl(["x509", "-pubkey", "-noout"], certificate)
    require(public == openssl(["pkey", "-pubout", "-passin", "pass:"], key))
    subject = openssl(["x509", "-subject", "-noout", "-nameopt", "RFC2253"], certificate)
    names = re.findall(rb"(?:subject=|,)CN=([^,\n]+)", subject)
    require(names == [hostname.encode("ascii")])
    # A sealed anonymous fd gives OpenSSL the exact pinned CA bytes, not a path
    # a trusted writer could replace during verification. No disk staging.
    descriptor = os.memfd_create("stage3-trust", os.MFD_ALLOW_SEALING)
    try:
        with os.fdopen(descriptor, "wb", closefd=False) as target:
            target.write(ca)
        fcntl.fcntl(descriptor, fcntl.F_ADD_SEALS,
                    fcntl.F_SEAL_WRITE | fcntl.F_SEAL_GROW | fcntl.F_SEAL_SHRINK | fcntl.F_SEAL_SEAL)
        openssl(["verify", "-trusted", "/proc/self/fd/" + str(descriptor),
                 "-no-CAfile", "-no-CApath", "-no-CAstore", "-purpose", "sslclient",
                 "-verify_hostname", hostname, "-check_ss_sig"], certificate, (descriptor,))
    finally:
        os.close(descriptor)


def check(identity_value, output_value, hostname, ca_sha256):
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
    check_tls(ssl, hostname, ca_sha256)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("identity_root")
    parser.add_argument("publication_root")
    parser.add_argument("hostname")
    parser.add_argument("ca_sha256", help="Independently approved SHA256 of the public CA PEM bytes")
    args = parser.parse_args()
    try:
        check(args.identity_root, args.publication_root, args.hostname, args.ca_sha256)
        print("Stage 3 identity/path admission passed")
        return 0
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.SubprocessError):
        # No filenames, certificate bytes, keys, machine identity or traceback.
        print("Stage 3 identity/path admission failed", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
