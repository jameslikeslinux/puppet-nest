"""Encrypted final-copy custody and isolated restore, never signer activation.

Plaintext key archives exist only in process memory. The backup mount receives
CMS authenticated envelopes, not raw keys or working directories. Completion
records are integrity/readback records, not independently trusted signatures;
restore also requires the independently selected exact public root.
"""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tarfile
import time
import uuid

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

FILES = ("signing.key", "public.json", "complete.json")
DESTINATION = Path("/nest/backup/joyride-evidence")
LIMIT = 65536


class CustodyError(Exception):
    """Fixed infrastructure custody failure; no application imports."""


def require(value):
    if not value:
        raise CustodyError("evidence_custody_failed")


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"),
                      ensure_ascii=False, allow_nan=False).encode("utf-8")


def directory(path):
    path = Path(path)
    require(path.is_absolute())
    for part in [*reversed(path.parents), path]:
        meta = part.lstat()
        require(stat.S_ISDIR(meta.st_mode) and not stat.S_ISLNK(meta.st_mode))
        require(meta.st_uid in (0, os.geteuid()) and not meta.st_mode & 0o022)
    meta = path.lstat()
    require(meta.st_uid == os.geteuid() and stat.S_IMODE(meta.st_mode) == 0o700)
    return path


def manifest(key):
    public = key.public_key().public_bytes_raw()
    return {"schema": 1, "kind": "joyride-installed-test-public-key-v1",
            "algorithm": "Ed25519", "public_key": public.hex(),
            "fingerprint": "sha256:" + hashlib.sha256(public).hexdigest()}


def inspect(path):
    path = directory(path)
    key = read_private(path / "signing.key", 64)
    require(len(key) == 32)
    expected = manifest(Ed25519PrivateKey.from_private_bytes(key))
    require(read_private(path / "public.json", 1024) == canonical(expected) + b"\n")
    require(read_private(path / "complete.json", 1024) == canonical({
        "schema": 1, "kind": "joyride-installed-test-key-complete-v1",
        "fingerprint": expected["fingerprint"]}) + b"\n")
    return expected


def write_private(path, value):
    data = canonical(value) + b"\n"
    require(len(data) <= 16384)
    write_bytes(path, data)


def read_private(path, limit=LIMIT):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    try:
        meta = os.fstat(fd)
        require(stat.S_ISREG(meta.st_mode) and stat.S_IMODE(meta.st_mode) == 0o600
                and meta.st_uid == os.geteuid() and meta.st_nlink == 1)
        data = os.read(fd, limit + 1)
        require(len(data) <= limit)
        return data
    finally:
        os.close(fd)


def fsync_directory(path):
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def write_bytes(path, data):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "wb") as stream:
        stream.write(data)
        stream.flush()
        os.fsync(stream.fileno())


def envelope(data, certificate, private_key=None):
    # AEAD, not the unauthenticated CBC eyaml format. No subprocess diagnostics
    # or plaintext output can reach the CLI log, including on decryption failure.
    command = ["openssl", "cms", "-binary", "-inform", "DER", "-outform", "DER"]
    if private_key is None:
        command += ["-encrypt", "-aes-256-gcm", "-recip", str(certificate)]
    else:
        command += ["-decrypt", "-recip", str(certificate), "-inkey", str(private_key)]
    result = subprocess.run(command, input=data, capture_output=True, timeout=30, check=False)
    require(result.returncode == 0 and 0 < len(result.stdout) <= LIMIT)
    return result.stdout


def validate_files(files, expected_public):
    require(set(files) == set(FILES) and re.fullmatch(r"[0-9a-f]{64}", expected_public))
    require(len(files["signing.key"]) == 32)
    public = manifest(Ed25519PrivateKey.from_private_bytes(files["signing.key"]))
    require(public["public_key"] == expected_public)
    require(files["public.json"] == canonical(public) + b"\n")
    require(files["complete.json"] == canonical({
        "schema": 1, "kind": "joyride-installed-test-key-complete-v1",
        "fingerprint": public["fingerprint"]}) + b"\n")
    return public


def capture(generation, expected_public):
    before = inspect(generation)
    require(before["public_key"] == expected_public)
    files = {name: read_private(generation / name, 1024) for name in FILES}
    require(validate_files(files, expected_public) == before)
    stream = io.BytesIO()
    with tarfile.open(fileobj=stream, mode="w", format=tarfile.USTAR_FORMAT) as archive:
        for name in FILES:
            entry = tarfile.TarInfo(name)
            entry.mode, entry.size = 0o600, len(files[name])
            archive.addfile(entry, io.BytesIO(files[name]))
    require(inspect(generation) == before)
    require(all(read_private(generation / name, 1024) == files[name] for name in FILES))
    return stream.getvalue(), before


def backup(generation, expected_public, certificate):
    plaintext, public = capture(generation, expected_public)
    ciphertext = envelope(plaintext, certificate)
    # Only completed ciphertext crosses onto the final backup mount. The
    # existing shared mount may be group-writable; the custody leaf may not be.
    # A hostile ancestor can deny service/replace ciphertext but cannot decrypt
    # it or satisfy restore's independent public-root and authenticated envelope.
    require(DESTINATION.parent.is_dir() and not DESTINATION.parent.is_symlink())
    if not DESTINATION.exists():
        DESTINATION.mkdir(mode=0o700)
    meta = DESTINATION.lstat()
    require(stat.S_ISDIR(meta.st_mode) and meta.st_uid == os.geteuid()
            and stat.S_IMODE(meta.st_mode) == 0o700)
    name = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime()) + "-" + uuid.uuid4().hex
    archive = DESTINATION / (name + ".cms")
    completion = DESTINATION / (name + ".complete.json")
    write_bytes(archive, ciphertext)
    require(read_private(archive) == ciphertext)
    record = {"schema": 1, "kind": "joyride-evidence-custody-v1", "complete": True,
              "archive": archive.name, "sha256": hashlib.sha256(ciphertext).hexdigest(),
              "bytes": len(ciphertext), "public_key": expected_public,
              "fingerprint": public["fingerprint"], "encryption": "CMS-AES-256-GCM"}
    write_private(completion, record)
    require(read_private(completion) == canonical(record) + b"\n")
    fsync_directory(DESTINATION)
    fsync_directory(DESTINATION.parent)
    # If publication is interrupted, preserve the partial ciphertext. Discovery
    # must require this exact completion; never sweep/delete other generations.
    return completion


def restore(completion, target, expected_public, certificate, private_key):
    directory(target.parent)
    require(not target.exists() and not target.is_symlink())
    data = read_private(completion, 2048)
    record = json.loads(data)
    require(data == canonical(record) + b"\n" and record.get("schema") == 1
            and record.get("kind") == "joyride-evidence-custody-v1"
            and record.get("complete") is True and record.get("public_key") == expected_public
            and record.get("encryption") == "CMS-AES-256-GCM")
    name = record.get("archive", "")
    require(re.fullmatch(r"[0-9]{8}T[0-9]{6}Z-[0-9a-f]{32}\.cms", name))
    require(completion.name == name[:-4] + ".complete.json")
    ciphertext = read_private(completion.parent / name)
    require(len(ciphertext) == record.get("bytes")
            and hashlib.sha256(ciphertext).hexdigest() == record.get("sha256"))
    plaintext = envelope(ciphertext, certificate, private_key)
    files = {}
    with tarfile.open(fileobj=io.BytesIO(plaintext), mode="r:") as archive:
        for member in archive:
            require(member.name in FILES and member.name not in files
                    and member.isfile() and member.mode == 0o600 and 0 < member.size <= 1024
                    and not member.pax_headers)
            source = archive.extractfile(member)
            if source is None:
                raise ValueError("invalid_custody_archive")
            with source:
                files[member.name] = source.read(1025)
    public = validate_files(files, expected_public)
    require(record.get("fingerprint") == public["fingerprint"])
    # Create only after decrypt/structure/key validation; do not extract tar paths.
    # Failure after mkdir preserves incomplete material for supervised inspection.
    target.mkdir(mode=0o700)
    for name in FILES:
        write_bytes(target / name, files[name])
    fsync_directory(target)
    fsync_directory(target.parent)
    require(inspect(target) == public)
    return public


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("backup", "restore"))
    parser.add_argument("--generation", type=Path)
    parser.add_argument("--public-key", required=True)
    parser.add_argument("--certificate", type=Path, default=Path("/etc/eyaml/keys/public_key.pkcs7.pem"))
    parser.add_argument("--private-key", type=Path)
    parser.add_argument("--completion", type=Path)
    parser.add_argument("--target", type=Path)
    args = parser.parse_args()
    os.umask(0o077)
    require(re.fullmatch(r"[0-9a-f]{64}", args.public_key))
    if args.action == "backup":
        require(args.generation is not None and args.private_key is None
                and args.completion is None and args.target is None)
        completion = backup(args.generation, args.public_key, args.certificate)
        print(canonical({"status": "encrypted_backup_readback", "completion": str(completion)}).decode())
    else:
        require(args.target is not None and args.completion is not None
                and args.private_key is not None and args.generation is None)
        public = restore(args.completion, args.target, args.public_key, args.certificate, args.private_key)
        print(canonical({"status": "isolated_restore_verified", **public}).decode())


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print("Evidence custody failed; preserve generations for inspection", file=sys.stderr)
        sys.exit(1)
