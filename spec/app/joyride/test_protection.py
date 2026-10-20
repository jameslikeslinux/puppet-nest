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

    def test_backup_target_refused_before_io(self):
        with patch.object(backup, 'command') as command, patch.object(backup.os, 'umask') as umask:
            with self.assertRaises(KeyError):
                backup.backup(Path('/scratch'), environment='arbitrary-namespace')
            command.assert_not_called()
            umask.assert_not_called()
        for environment, other in (('production', 'test'), ('test', 'production')):
            with patch.object(backup, 'command') as command:
                with self.assertRaisesRegex(backup.BackupError, 'environment_destination_mismatch'):
                    backup.backup(Path('/scratch'), backup.TARGETS[other][3], environment=environment)
                command.assert_not_called()

    def test_fixed_environment_capture_and_completion_receipt(self):
        # Synthetic subprocesses only; real staging, tar validation and final
        # publication exercise the complete capture path for both targets.
        for environment, (namespace, application, database, _) in backup.TARGETS.items():
            with self.subTest(environment=environment), tempfile.TemporaryDirectory() as root:
                root = Path(root)
                stage = root / 'scratch'
                stage.mkdir()
                destination = root / 'final'
                target = (namespace, application, database, destination)
                calls = []

                def command(args, output=None, data=None):
                    calls.append(args)
                    self.assertEqual(args[:4], ['kubectl', '--request-timeout=60s', '-n', namespace])
                    if args[4] == 'get':
                        selector = args[args.index('-l') + 1]
                        self.assertIn(selector, ('app=' + application,
                                                'cnpg.io/cluster=' + database + ',cnpg.io/instanceRole=primary'))
                        name = application if selector.startswith('app=') else database
                        return json.dumps({'items': [{'metadata': {'name': name, 'uid': name},
                                                      'status': {'conditions': [{'type': 'Ready', 'status': 'True'}]},
                                                      'spec': {'containers': [{'name': 'web', 'image': 'synthetic@sha256:fixed'}]}}]}).encode()
                    if args[-1] == backup.SCAN:
                        return b'{}'
                    if args[-1] == backup.ARCHIVE:
                        with tarfile.open(fileobj=output, mode='w'):
                            pass
                        return None
                    self.assertIn('pg_dump', args)
                    assert output is not None
                    output.write(b'synthetic PostgreSQL archive')

                with patch.dict(backup.TARGETS, {environment: target}), patch.object(backup, 'command', side_effect=command), \
                        patch.object(backup.subprocess, 'run') as parser:
                    parser.return_value.returncode = 0
                    if environment == 'test':
                        result = backup.backup(stage)
                    else:
                        result = backup.backup(stage, environment=environment)
                    parser_args = parser.call_args.args[0]
                    self.assertEqual(parser_args[:4], ['kubectl', '--request-timeout=60s', '-n', namespace])
                    self.assertIn(database, parser_args)
                    self.assertIn('pg_restore', parser_args)
                self.assertEqual(result['environment'], environment)
                self.assertTrue(result['complete'])
                self.assertEqual(backup.sha256(destination / result['archive']), result['sha256'])
                self.assertEqual(list(stage.iterdir()), [])
                self.assertEqual(len(calls), 7)

    def opener(self, bad=None, environment='test'):
        fixtures = {'/health/ready': {'status': 'ready'}, '/api/csrf': {'csrf_token': 'a' * 64},
                    '/maps/current': {'sha256': '0' * 64, 'url': '/maps/synthetic.pmtiles'}, '/': '<html>synthetic</html>'}
        def open_url(request, timeout):
            path = request.selector
            origin, host = monitor.TARGETS[environment]
            self.assertEqual(request.get_header('Host'), host)
            self.assertEqual(request.full_url, origin + path)
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

    def test_production_monitor_uses_only_fixed_anonymous_production_paths(self):
        self.assertIn('passed', monitor.probe(self.opener(environment='production'), environment='production'))
        for value in ({'status': 'unavailable'}, 'x' * 65537):
            with self.assertRaises(ValueError):
                monitor.probe(self.opener(value, environment='production'), environment='production')

    def test_monitor_refuses_unknown_target_before_any_request(self):
        with patch.object(monitor.urllib.request, 'build_opener') as opener:
            with self.assertRaises(KeyError):
                monitor.probe(environment='http://untrusted.invalid')
            opener.assert_not_called()

    def test_redirect_is_not_followed(self):
        self.assertIsNone(monitor.NoRedirect().redirect_request(None, None, 302, '', {}, 'http://other.invalid'))


if __name__ == '__main__':
    unittest.main()
