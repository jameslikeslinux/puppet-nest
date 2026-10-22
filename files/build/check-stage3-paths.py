#!/usr/bin/env python3
"""Admit private Stage 3 identity; optionally capture/install in a disposable build."""

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import pwd
import re
import shutil
import stat
import subprocess
import sys
import tempfile


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
    ca = read_material(ssl / "certs/ca.pem")
    certificate = read_material(ssl / ("certs/" + hostname + ".pem"))
    key = read_material(ssl / ("private_keys/" + hostname + ".pem"))
    check_tls_bytes(ca, certificate, key, hostname, ca_sha256)


def check_tls_bytes(ca, certificate, key, hostname, ca_sha256):
    require(re.fullmatch(r"[0-9a-f]{64}", ca_sha256) is not None)
    require(hashlib.sha256(ca).hexdigest() == ca_sha256)
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


def identity_inventory(identity):
    # Metadata only, private to this process. Compare the complete set before
    # and after every read, including directories (add/remove/rename detection).
    paths = [identity, identity / "etc", identity / "etc/machine-id",
             identity / "etc/puppetlabs", identity / "etc/puppetlabs/puppet"]
    ssl = identity / "etc/puppetlabs/puppet/ssl"
    for directory, directories, files in os.walk(ssl, followlinks=False, onerror=walk_error):
        paths.append(Path(directory))
        paths.extend(Path(directory) / name for name in files)
        require(len(paths) + len(directories) <= 4096)
    fields = ("st_dev", "st_ino", "st_size", "st_mode", "st_uid", "st_gid", "st_mtime_ns", "st_ctime_ns")
    result = {}
    for path in paths:
        info = path.lstat()
        require(stat.S_ISDIR(info.st_mode) or stat.S_ISREG(info.st_mode))
        result[path.relative_to(identity)] = tuple(getattr(info, f) for f in fields)
    return result


def reference_name(value):
    # Opaque, caller-selected identity generation, never a secret-content digest.
    require(re.fullmatch(r"[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}", value) is not None)


def reference_record(inventory, material, hostname, ca_sha256, reference):
    reference_name(reference)
    entries = {}
    for relative, info in inventory.items():
        entries[str(relative)] = {
            "mode": stat.S_IMODE(info[3]), "uid": info[4], "gid": info[5],
            "sha256": hashlib.sha256(material[relative]).hexdigest() if relative in material else None,
        }
    # This entire record is PRIVATE, including file names and key digests.
    record = {"schema": 1, "reference": reference, "host": hostname, "ca_sha256": ca_sha256, "entries": entries}
    return (json.dumps(record, sort_keys=True, separators=(",", ":")) + "\n").encode("ascii")


def read_reference(identity, reference):
    reference_name(reference)
    require(identity.name == reference)
    require(stat.S_IMODE(identity.lstat().st_mode) == 0o700)
    path = identity / ".nest-identity.json"
    safe_file(path, {0}, private=True)
    require(stat.S_IMODE(path.lstat().st_mode) == 0o400)
    return read_material(path)


def capture(identity_value, output_value, hostname, ca_sha256, reference=None):
    check(identity_value, output_value, hostname, ca_sha256)
    identity = Path(identity_value)
    receipt = read_reference(identity, reference) if reference is not None else None
    before = identity_inventory(identity)
    material = {}
    total = 0
    for relative, info in before.items():
        if stat.S_ISREG(info[3]):
            value = read_material(identity / relative)
            total += len(value)
            require(total <= 16 * 1024 * 1024)
            material[relative] = value
    check(identity_value, output_value, hostname, ca_sha256)
    require(before == identity_inventory(identity))
    # Admission of the actual captured bytes, not a later reopen of the source.
    machine = material[Path("etc/machine-id")]
    require(re.fullmatch(rb"[0-9a-f]{32}\n?", machine) is not None and machine.strip() != b"0" * 32)
    ssl = Path("etc/puppetlabs/puppet/ssl")
    check_tls_bytes(material[ssl / "certs/ca.pem"], material[ssl / ("certs/" + hostname + ".pem")],
                    material[ssl / ("private_keys/" + hostname + ".pem")], hostname, ca_sha256)
    if reference is not None:
        require(receipt == read_reference(identity, reference))
        require(receipt == reference_record(before, material, hostname, ca_sha256, reference))
    return before, material


def install_capture(inventory, material, destination):
    # Only the disposable build root is a supported destination. Private local
    # staging is removed on failure too; no secret bytes or digests are reported.
    etc = destination / "etc"
    puppet = etc / "puppetlabs/puppet"
    for path in (etc, etc / "puppetlabs", puppet):
        safe_directory(path, {0}, {0})
    for path in (etc / "machine-id", puppet / "ssl"):
        require(not path.is_symlink())
    # Stage on the destination filesystem for rename, never on shared /nest or
    # a separate /run tmpfs. The outer directory stays mode 0700 throughout.
    with tempfile.TemporaryDirectory(prefix=".nest-stage3-identity-", dir=puppet) as temporary:
        stage = Path(temporary)
        for relative, info in inventory.items():
            path = stage / relative
            if stat.S_ISDIR(info[3]):
                path.mkdir(parents=True, exist_ok=True, mode=0o700)
            else:
                with path.open("xb") as stream:
                    os.fchmod(stream.fileno(), 0o600)
                    stream.write(material[relative])
                    stream.flush()
                    os.fsync(stream.fileno())
        # Restore admitted ownership/modes only after the whole tree is private.
        for relative, info in reversed(list(inventory.items())):
            if relative == Path("."):
                continue
            path = stage / relative
            os.chown(path, info[4], info[5])
            path.chmod(stat.S_IMODE(info[3]))
        # A failed install aborts this build; it is not a live-host repair or a
        # resumable identity migration. Preserve no second persistent key tree.
        if (puppet / "ssl").exists():
            # OverlayFS may refuse renaming a base-image (lower) directory
            # even on the same device. This is a disposable build replacement,
            # not an atomic live migration; removal failure stops publication.
            shutil.rmtree(puppet / "ssl")
        os.rename(stage / "etc/puppetlabs/puppet/ssl", puppet / "ssl")
        os.replace(stage / "etc/machine-id", etc / "machine-id")
        require((etc / "machine-id").read_bytes() == material[Path("etc/machine-id")])
        ssl = Path("etc/puppetlabs/puppet/ssl")
        expected = {p.relative_to(ssl): value for p, value in material.items() if ssl in p.parents}
        actual = {p.relative_to(puppet / "ssl"): p.read_bytes() for p in (puppet / "ssl").rglob("*") if p.is_file()}
        require(actual == expected)


def publish_reference(identity_value, output_value, hostname, ca_sha256, reference):
    # Explicit private local capture only. No key generation, network, snapshot,
    # alias, source mutation, or replacement of a prior/partial generation.
    require(os.geteuid() == 0)
    reference_name(reference)
    output = canonical(output_value)
    require(output.name == reference and not output.exists())
    safe_directory(output.parent, {0}, {0})
    require(stat.S_IMODE(output.parent.lstat().st_mode) == 0o700)
    inventory, material = capture(identity_value, output_value, hostname, ca_sha256)
    output.mkdir(mode=0o700)  # Atomic no-clobber reservation, including concurrent publishers.
    # Failed output stays incomplete and cannot be retried/overwritten implicitly.
    (output / "etc/puppetlabs/puppet").mkdir(parents=True, mode=0o700)
    install_capture(inventory, material, output)
    installed, copied = capture(str(output), identity_value, hostname, ca_sha256)
    require(material == copied)
    record = reference_record(installed, copied, hostname, ca_sha256, reference)
    require(len(record) <= 1024 * 1024)
    # Persist every installed directory entry before the completion marker. The
    # marker is last; absence means incomplete, never a usable identity input.
    for relative, info in reversed(list(installed.items())):
        if stat.S_ISDIR(info[3]):
            descriptor = os.open(output / relative, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
            try:
                os.fsync(descriptor)
            finally:
                os.close(descriptor)
    path = output / ".nest-identity.json"
    # An interrupted/failed marker write is rejected by exact canonical readback.
    with path.open("xb") as stream:
        os.fchmod(stream.fileno(), 0o400)
        stream.write(record)
        stream.flush()
        os.fsync(stream.fileno())
    for directory in (output, output.parent):
        descriptor = os.open(directory, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            os.fsync(descriptor)
        finally:
            os.close(descriptor)
    capture(str(output), identity_value, hostname, ca_sha256, reference)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("identity_root")
    parser.add_argument("publication_root")
    parser.add_argument("hostname")
    parser.add_argument("ca_sha256", help="Independently approved SHA256 of the public CA PEM bytes")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--install", action="store_true", help="Capture and install identity inside a disposable Podman build container only")
    mode.add_argument("--publish-reference", metavar="UUID", help="Explicitly capture a new private local generation at publication_root; never overwrite")
    parser.add_argument("--identity-reference", metavar="UUID", help="Require the exact completed private generation; read-only unless --install")
    args = parser.parse_args()
    try:
        if args.publish_reference:
            require(args.identity_reference is None)
            publish_reference(args.identity_root, args.publication_root, args.hostname, args.ca_sha256, args.publish_reference)
        elif args.install:
            require(os.geteuid() == 0 and Path("/run/.containerenv").is_file())
            inventory, material = capture(args.identity_root, args.publication_root, args.hostname, args.ca_sha256, args.identity_reference)
            install_capture(inventory, material, Path("/"))
        elif args.identity_reference is not None:
            capture(args.identity_root, args.publication_root, args.hostname, args.ca_sha256, args.identity_reference)
        else:
            check(args.identity_root, args.publication_root, args.hostname, args.ca_sha256)
        print("Stage 3 identity/path admission passed")
        return 0
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.SubprocessError):
        # No filenames, certificate bytes, keys, machine identity or traceback.
        print("Stage 3 identity/path admission failed", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
