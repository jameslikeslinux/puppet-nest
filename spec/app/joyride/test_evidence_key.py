"""Disposable private-generation lifecycle contracts; no managed key created."""
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'files/app/joyride'))
SPEC = importlib.util.spec_from_file_location('evidence_key', ROOT / 'files/app/joyride/evidence_key.py')
assert SPEC is not None and SPEC.loader is not None
keytool = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(keytool)
from installed_test_producer import EvidenceError


class KeyLifecycle(unittest.TestCase):
    def setUp(self):
        # A private store cannot be nested under a shared /tmp or CI build root.
        self.folder = tempfile.TemporaryDirectory(dir=Path.home())
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name).resolve()
        self.root.chmod(0o700)
        self.generation = self.root / 'generation-1'

    def test_create_and_readback_bind_real_private_key_and_completion(self):
        public = keytool.create(self.generation)
        self.assertEqual(public, keytool.inspect(self.generation))
        self.assertEqual(len(public['public_key']), 64)
        self.assertEqual(set(public), {'schema', 'kind', 'algorithm', 'public_key', 'fingerprint'})
        self.assertEqual(self.generation.stat().st_mode & 0o777, 0o700)
        for name in ('signing.key', 'public.json', 'complete.json'):
            self.assertEqual((self.generation / name).stat().st_mode & 0o777, 0o600)
        key = keytool.private_key(self.generation / 'signing.key')
        self.assertEqual(key.public_key().public_bytes_raw().hex(), public['public_key'])

    def test_existing_generation_never_rotates_or_repairs(self):
        public = keytool.create(self.generation)
        with self.assertRaises(FileExistsError):
            keytool.create(self.generation)
        self.assertEqual(keytool.inspect(self.generation), public)
        (self.generation / 'complete.json').unlink()
        with self.assertRaises(FileNotFoundError):
            keytool.inspect(self.generation)
        with self.assertRaises(FileExistsError):
            keytool.create(self.generation)

    def test_partial_failure_keeps_private_material_and_refuses_inspection(self):
        with patch.object(keytool, 'write_private', side_effect=OSError('synthetic disk failure')):
            with self.assertRaises(OSError):
                keytool.create(self.generation)
        self.assertEqual(len((self.generation / 'signing.key').read_bytes()), 32)
        with self.assertRaises(FileNotFoundError):
            keytool.inspect(self.generation)
        with self.assertRaises(FileExistsError):
            keytool.create(self.generation)

    def test_pair_or_marker_tampering_fails_closed(self):
        keytool.create(self.generation)
        marker = self.generation / 'complete.json'
        value = json.loads(marker.read_text())
        value['fingerprint'] = 'sha256:' + '0' * 64
        marker.write_bytes(keytool.canonical(value) + b'\n')
        with self.assertRaises(EvidenceError):
            keytool.inspect(self.generation)

    def test_second_generation_is_distinct_without_activating_either(self):
        first = keytool.create(self.generation)
        second = keytool.create(self.root / 'generation-2')
        self.assertNotEqual(first['fingerprint'], second['fingerprint'])
        self.assertEqual(keytool.inspect(self.generation), first)
        self.assertFalse((self.root / 'active').exists())

    def test_shared_store_or_symlinked_ancestor_is_refused(self):
        self.root.chmod(0o750)
        with self.assertRaises(EvidenceError):
            keytool.create(self.generation)
        self.root.chmod(0o700)
        alias = self.root / 'alias'
        alias.symlink_to(self.root, target_is_directory=True)
        with self.assertRaises(EvidenceError):
            keytool.create(alias / 'generation-1')
        self.assertFalse(self.generation.exists())

    def test_shared_generation_and_linked_metadata_are_refused(self):
        keytool.create(self.generation)
        self.generation.chmod(0o750)
        with self.assertRaises(EvidenceError):
            keytool.inspect(self.generation)
        self.generation.chmod(0o700)
        public = self.generation / 'public.json'
        os.link(public, self.root / 'linked-public')
        with self.assertRaises(EvidenceError):
            keytool.inspect(self.generation)


if __name__ == '__main__':
    unittest.main()
