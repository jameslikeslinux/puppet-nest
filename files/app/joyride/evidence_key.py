"""Private immutable Ed25519 generation lifecycle; never a Joy approval key.

Create only inside an independently managed private store. No automatic repair,
rotation, activation, consumer trust installation or private-key export exists.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import stat
import sys

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

from installed_test_producer import canonical, private_key, require, write_private


def directory(path):
    """Reject symlinked ancestors and writable/shared key-store directories."""
    path = Path(path)
    require(path.is_absolute())
    for part in [*reversed(path.parents), path]:
        meta = part.lstat()
        require(stat.S_ISDIR(meta.st_mode) and not stat.S_ISLNK(meta.st_mode))
        # System ancestors can be root-owned, but cannot be group/world writable.
        require(meta.st_uid in (0, os.geteuid()) and not meta.st_mode & 0o022)
    meta = path.lstat()
    require(meta.st_uid == os.geteuid() and stat.S_IMODE(meta.st_mode) == 0o700)
    return path


def manifest(key):
    public = key.public_key().public_bytes_raw()
    return {"schema": 1, "kind": "joyride-installed-test-public-key-v1",
            "algorithm": "Ed25519", "public_key": public.hex(),
            "fingerprint": "sha256:" + hashlib.sha256(public).hexdigest()}


def read_manifest(path):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    try:
        meta = os.fstat(fd)
        require(stat.S_ISREG(meta.st_mode) and stat.S_IMODE(meta.st_mode) == 0o600
                and meta.st_uid == os.geteuid() and meta.st_nlink == 1)
        data = os.read(fd, 1025)
        require(len(data) <= 1024)
        value = json.loads(data)
        require(data == canonical(value) + b"\n")
        return value
    finally:
        os.close(fd)


def inspect(path):
    path = directory(path)
    key = private_key(path / "signing.key")
    expected = manifest(key)
    require(read_manifest(path / "public.json") == expected)
    # This is the completion marker, not an active-consumer pointer.
    require(read_manifest(path / "complete.json") == {
        "schema": 1, "kind": "joyride-installed-test-key-complete-v1",
        "fingerprint": expected["fingerprint"]})
    return expected


def create(path):
    path = Path(path)
    directory(path.parent)
    require(path.name not in ("", ".", ".."))
    # Atomic exclusive directory creation serializes concurrent creators. Never
    # overwrite, regenerate or remove an incomplete generation after failure.
    path.mkdir(mode=0o700)
    key = Ed25519PrivateKey.generate()
    fd = os.open(path / "signing.key", os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "wb") as stream:
        stream.write(key.private_bytes_raw())
        stream.flush()
        os.fsync(stream.fileno())
    public = manifest(key)
    write_private(path / "public.json", public)
    write_private(path / "complete.json", {
        "schema": 1, "kind": "joyride-installed-test-key-complete-v1",
        "fingerprint": public["fingerprint"]})
    # Persist directory entries and their parent before returning success.
    for folder in (path, path.parent):
        fd = os.open(folder, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)
    return inspect(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("create", "inspect"))
    parser.add_argument("generation", type=Path)
    args = parser.parse_args()
    value = create(args.generation) if args.action == "create" else inspect(args.generation)
    # Public verification material only; never private bytes or exception text.
    print(canonical(value).decode())


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print("Evidence key operation failed; preserve generation for inspection", file=sys.stderr)
        sys.exit(1)
