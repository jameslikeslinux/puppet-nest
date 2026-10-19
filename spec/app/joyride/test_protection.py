"""Synthetic fixtures: publication failures and anonymous probe contracts."""
import importlib.util
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'files/app/joyride' / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


backup = load('backup')
monitor = load('monitor')


class ProtectionTests(unittest.TestCase):
    def test_publish_and_private_permissions(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            payload = root / 'payload'
            payload.write_bytes(b'synthetic backup')
            destination = root / 'final'
            destination.mkdir()
            result = backup.publish(payload, destination, {'schema': 1})
            self.assertEqual(backup.sha256(destination / result['archive']), result['sha256'])
            self.assertTrue(json.loads(next(destination.glob('*.json')).read_text())['complete'])
            self.assertEqual((destination / result['archive']).stat().st_mode & 0o777, 0o600)
            self.assertEqual(next(destination.glob('*.json')).stat().st_mode & 0o777, 0o600)

    def test_failed_copy_preserves_known_good_generation(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            source = root / 'payload'
            source.write_bytes(b'synthetic backup')
            destination = root / 'final'
            destination.mkdir()
            good = backup.publish(source, destination, {})
            with patch.object(backup.shutil, 'copyfileobj', side_effect=OSError('synthetic disk full')):
                with self.assertRaises(OSError):
                    backup.publish(source, destination, {})
            self.assertEqual(len(list(destination.glob('*.tar'))), 1)
            self.assertEqual(backup.sha256(destination / good['archive']), good['sha256'])
            self.assertEqual(len(list(destination.glob('*.json'))), 1)

    def test_failed_readback_never_commits(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            source = root / 'payload'
            source.write_bytes(b'synthetic')
            destination = root / 'final'
            destination.mkdir()
            with patch.object(backup, 'sha256', side_effect=['a', 'b']):
                with self.assertRaises(backup.BackupError):
                    backup.publish(source, destination, {})
            self.assertEqual(list(destination.iterdir()), [])

    def test_name_collision_never_removes_existing_generation(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            source = root / 'payload'
            source.write_bytes(b'synthetic backup')
            destination = root / 'final'
            destination.mkdir()
            with patch.object(backup.time, 'strftime', return_value='fixed'), patch.object(backup.uuid, 'uuid4') as uid:
                uid.return_value.hex = 'collision'
                good = backup.publish(source, destination, {})
                with self.assertRaises(FileExistsError):
                    backup.publish(source, destination, {})
            self.assertEqual(backup.sha256(destination / good['archive']), good['sha256'])
            self.assertTrue(next(destination.glob('*.json')).is_file())

    def test_archive_rejects_symlink_and_traversal(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / 'files.tar'
            for name, kind in (('../secret', tarfile.REGTYPE), ('private/link', tarfile.SYMTYPE)):
                with tarfile.open(path, 'w') as archive:
                    entry = tarfile.TarInfo(name)
                    entry.type = kind
                    archive.addfile(entry)
                with self.assertRaises(backup.BackupError):
                    backup.verify_files(path, {})

    def test_archive_rejects_missing_or_changed_files(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / 'files.tar'
            with tarfile.open(path, 'w'):
                pass
            backup.verify_files(path, {})
            with self.assertRaises(backup.BackupError):
                backup.verify_files(path, {'private/synthetic': 'missing'})

    def test_staging_on_backup_target_refused_before_capture(self):
        with self.assertRaises(backup.BackupError):
            backup.backup(Path('/nest/backup/staging'), Path('/nest/backup/joyride-test'))

    def opener(self, bad=None):
        fixtures = {'/health/ready': {'status': 'ready'}, '/api/csrf': {'csrf_token': 'a' * 64},
                    '/maps/current': {'sha256': '0' * 64, 'url': '/maps/synthetic.pmtiles'}, '/': '<html>synthetic</html>'}
        def open_url(request, timeout):
            path = request.selector
            self.assertEqual(request.get_header('Host'), 'joyride-test.eyrie')
            self.assertLessEqual(timeout, 10)
            value = bad if bad is not None and path == '/health/ready' else fixtures[path]
            body = value.encode() if isinstance(value, str) else json.dumps(value).encode()
            response = io.BytesIO(body)
            response.status = 200
            response.headers = {'Content-Type': 'text/html' if path == '/' else 'application/json'}
            return response
        return open_url

    def test_monitor_checks_real_contract_without_credentials(self):
        self.assertIn('passed', monitor.probe(self.opener()))

    def test_monitor_rejects_invalid_ready_and_oversize(self):
        for value in ({'status': 'unavailable'}, 'x' * 65537):
            with self.assertRaises(ValueError):
                monitor.probe(self.opener(value))

    def test_redirect_is_not_followed(self):
        self.assertIsNone(monitor.NoRedirect().redirect_request(None, None, 302, '', {}, 'http://other.invalid'))


if __name__ == '__main__':
    unittest.main()
