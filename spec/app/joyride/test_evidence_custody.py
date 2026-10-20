"""Actual authenticated-encryption/restore fixtures, disposable key/certificate."""
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "files/app/joyride"))
import evidence_custody as custody
from evidence_custody import CustodyError as EvidenceError, canonical
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey


class CustodyContracts(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(dir=Path.home())
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.root.chmod(0o700)
        self.destination = self.root / "backup"
        self.generation = self.root / "original"
        self.generation.mkdir(mode=0o700)
        fixture_key = Ed25519PrivateKey.generate()
        self.public = custody.manifest(fixture_key)
        custody.write_bytes(self.generation / "signing.key", fixture_key.private_bytes_raw())
        custody.write_private(self.generation / "public.json", self.public)
        custody.write_private(self.generation / "complete.json", {
            "schema": 1, "kind": "joyride-installed-test-key-complete-v1",
            "fingerprint": self.public["fingerprint"]})
        self.key, self.cert = self.root / "recipient.key", self.root / "recipient.pem"
        subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
                        "-keyout", str(self.key), "-out", str(self.cert), "-days", "1",
                        "-subj", "/CN=Disposable Joyride custody fixture"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True, timeout=30)
        self.patcher = patch.object(custody, "DESTINATION", self.destination)
        self.patcher.start()
        self.addCleanup(self.patcher.stop)

    def backup(self):
        return custody.backup(self.generation, self.public["public_key"], self.cert)

    def restore(self, receipt, target=None, public=None):
        return custody.restore(receipt, target or self.root / "restored",
                               public or self.public["public_key"], self.cert, self.key)

    def test_actual_encrypted_final_copy_and_independent_isolated_restore(self):
        receipt = self.backup()
        record = json.loads(receipt.read_bytes())
        encrypted = (self.destination / record["archive"]).read_bytes()
        self.assertNotIn((self.generation / "signing.key").read_bytes(), encrypted)
        self.assertEqual(record["encryption"], "CMS-AES-256-GCM")
        self.assertEqual(self.destination.stat().st_mode & 0o777, 0o700)
        self.assertEqual(receipt.stat().st_mode & 0o777, 0o600)
        self.assertEqual((self.destination / record["archive"]).stat().st_mode & 0o777, 0o600)
        # Make the original unavailable before recovery; restore cannot read it.
        self.generation.rename(self.root / "unavailable-original")
        self.assertEqual(self.restore(receipt), self.public)
        self.assertEqual(custody.inspect(self.root / "restored"), self.public)
        self.assertEqual({p.name for p in self.destination.iterdir()}, {receipt.name, record["archive"]})

    def test_no_overwrite_or_rotation_and_distinct_backups(self):
        first, second = self.backup(), self.backup()
        self.assertNotEqual(first, second)
        self.restore(first)
        with self.assertRaises(EvidenceError):
            self.restore(second)
        self.assertEqual(custody.inspect(self.generation), self.public)
        self.assertEqual(custody.inspect(self.root / "restored"), self.public)

    def test_wrong_independent_public_root_fails_before_target_creation(self):
        receipt = self.backup()
        with self.assertRaises(EvidenceError):
            self.restore(receipt, public="0" * 64)
        self.assertFalse((self.root / "restored").exists())

    def test_ciphertext_tampering_fails_even_with_rewritten_checksum(self):
        receipt = self.backup()
        record = json.loads(receipt.read_bytes())
        archive = self.destination / record["archive"]
        data = bytearray(archive.read_bytes())
        data[-1] ^= 1
        archive.write_bytes(data)
        record["sha256"] = custody.hashlib.sha256(data).hexdigest()
        receipt.write_bytes(canonical(record) + b"\n")
        with self.assertRaises(EvidenceError):
            self.restore(receipt)
        self.assertFalse((self.root / "restored").exists())

    def test_incomplete_and_wrong_checksum_refused(self):
        receipt = self.backup()
        record = json.loads(receipt.read_bytes())
        for field, value in (("complete", False), ("sha256", "0" * 64), ("archive", "../escape.cms")):
            changed = dict(record, **{field: value})
            receipt.write_bytes(canonical(changed) + b"\n")
            with self.assertRaises(EvidenceError):
                self.restore(receipt)
        self.assertFalse((self.root / "restored").exists())

    def test_shared_symlinked_or_hardlinked_backup_is_refused(self):
        receipt = self.backup()
        receipt.chmod(0o640)
        with self.assertRaises(EvidenceError):
            self.restore(receipt)
        receipt.chmod(0o600)
        os.link(receipt, self.root / "linked-receipt")
        with self.assertRaises(EvidenceError):
            self.restore(receipt)
        alias = self.root / "alias.complete.json"
        alias.symlink_to(receipt)
        with self.assertRaises(OSError):
            self.restore(alias)

    def test_shared_backup_leaf_is_not_repaired(self):
        self.destination.mkdir(mode=0o750)
        with self.assertRaises(EvidenceError):
            self.backup()
        self.assertEqual(self.destination.stat().st_mode & 0o777, 0o750)
        self.assertEqual(list(self.destination.iterdir()), [])

    def test_malicious_tar_is_never_extracted(self):
        receipt = self.backup()
        for name, kind in (("../escape", tarfile.REGTYPE), ("signing.key", tarfile.SYMTYPE)):
            stream = io.BytesIO()
            with tarfile.open(fileobj=stream, mode="w") as archive:
                entry = tarfile.TarInfo(name)
                entry.type, entry.mode = kind, 0o600
                archive.addfile(entry)
            with patch.object(custody, "envelope", return_value=stream.getvalue()):
                with self.assertRaises(EvidenceError):
                    self.restore(receipt)
        self.assertFalse((self.root / "restored").exists())
        self.assertFalse((self.root / "escape").exists())

    def test_failure_preserves_partial_ciphertext_without_completion(self):
        with patch.object(custody, "write_private", side_effect=OSError("fixture failure")):
            with self.assertRaises(OSError):
                self.backup()
        self.assertEqual(len(list(self.destination.glob("*.cms"))), 1)
        self.assertEqual(list(self.destination.glob("*.complete.json")), [])
        self.assertEqual(custody.inspect(self.generation), self.public)

    def test_restore_failure_preserves_partial_generation(self):
        receipt = self.backup()
        original = custody.write_bytes
        calls = []

        def interrupted(path, data):
            calls.append(path)
            if len(calls) == 2:
                raise OSError("fixture interruption")
            original(path, data)

        with patch.object(custody, "write_bytes", side_effect=interrupted):
            with self.assertRaises(OSError):
                self.restore(receipt)
        self.assertEqual(len((self.root / "restored/signing.key").read_bytes()), 32)
        with self.assertRaises(EvidenceError):
            self.restore(receipt)


if __name__ == "__main__":
    unittest.main()
