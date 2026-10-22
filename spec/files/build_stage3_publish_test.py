#!/usr/bin/env python3
"""Real filesystem/rsync and fake ZFS publication faults; no live datasets."""

import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

PROJECT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('stage3_publish', PROJECT / 'files/build/publish-stage3-root.py')
assert SPEC is not None and SPEC.loader is not None
PUB = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PUB)


class PublishTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.source = self.base / 'offline'
        self.source.mkdir()
        (self.source / 'etc').mkdir()
        (self.source / 'etc/config').write_bytes(b'synthetic fixture only\n')
        (self.source / 'etc/key').write_bytes(b'not a real key\n')
        (self.source / 'etc/key').chmod(0o600)
        os.link(self.source / 'etc/config', self.source / 'etc/linked')
        (self.source / 'link').symlink_to('etc/config')
        os.setxattr(self.source / 'etc/config', 'user.fixture', b'fixture value')
        self.releases = self.base / 'releases'
        self.parent = self.releases / 'fixture-release/hosts'
        self.parent.mkdir(parents=True, mode=0o700)
        self.destination = self.parent / 'fixture-host'
        self.args = [str(self.source), 'fixture-host', 'fixture-release', '123', 'sha256:' + 'a' * 64]
        self.parent_row = ['pool/releases/hosts', '123', str(self.parent), 'yes', 'off']
        self.source_row = ['pool/offline', '456', str(self.source), 'yes', 'on']
        self.created = ['pool/releases/hosts/fixture-host', '789', str(self.destination), 'yes', 'off']
        self.commands = []
        self.sealed = False

    def filesystem(self, path, readonly, guid=None, parent=False):
        row = self.parent_row if path == self.parent else self.source_row if path == self.source else self.created
        self.assertEqual(row[4], readonly)
        self.assertTrue(guid is None or row[1] == guid)
        return list(row)

    def command(self, arguments):
        self.commands.append(arguments)
        if arguments[0] == 'rsync':
            return subprocess.run(arguments, capture_output=True, text=True, check=True).stdout
        if arguments[:3] == ['zfs', 'set', 'readonly=on']:
            self.sealed = True
            self.created[4] = 'on'
        return ''

    def observe(self, root, guid, release, expectations):
        self.assertTrue(self.sealed)
        self.assertEqual(guid, '789')
        return self.created[:4] + ['on', release, expectations]

    def publish(self, command=None, filesystem=None):
        with patch.object(PUB.ROOT, 'BASE', self.releases), patch.object(PUB.ROOT, 'safe_ancestors'), \
                patch.object(PUB.ROOT, 'observe', side_effect=self.observe), \
                patch.object(PUB.os, 'geteuid', return_value=0), \
                patch.object(PUB, 'filesystem', side_effect=filesystem or self.filesystem), \
                patch.object(PUB, 'command', side_effect=command or self.command):
            return PUB.publish(*self.args)

    def test_real_rsync_preserves_exact_identity_and_no_legacy_alias(self):
        before = PUB.ROOT.content_digest(self.source)
        result = self.publish()
        self.assertEqual(result, {'path': str(self.destination), 'dataset_guid': '789', 'content_digest': before})
        self.assertEqual(PUB.ROOT.content_digest(self.source), before)
        self.assertEqual(PUB.ROOT.content_digest(self.destination), before)
        self.assertEqual((self.destination / 'etc/key').stat().st_mode & 0o777, 0o600)
        self.assertEqual((self.destination / 'etc/config').stat().st_ino, (self.destination / 'etc/linked').stat().st_ino)
        operations = [args[:2] for args in self.commands]
        self.assertEqual(operations, [['zfs', 'create'], ['zfs', 'mount'], ['rsync', '--archive'], ['zpool', 'sync'], ['zfs', 'set']])
        create = self.commands[0]
        self.assertIn('canmount=noauto', create)
        self.assertIn('org.nest:expectations=' + self.args[4], create)
        self.assertNotIn('--delete', self.commands[2])

    def test_existing_path_including_incomplete_and_symlink_refuses(self):
        self.destination.mkdir()
        with self.assertRaises(FileExistsError):
            self.publish()
        self.assertEqual(self.commands, [])
        self.destination.rmdir()
        self.destination.symlink_to(self.source)
        with self.assertRaises(FileExistsError):
            self.publish()
        self.assertEqual(self.commands, [])

    def test_repeat_success_refuses_without_recopy(self):
        self.publish()
        self.commands.clear()
        with self.assertRaises(FileExistsError):
            self.publish()
        self.assertEqual(self.commands, [])

    def test_all_native_failures_retain_reservation_and_never_destroy(self):
        for failure in ['create', 'mount', 'copy', 'flush', 'seal']:
            with self.subTest(failure=failure):
                # Isolate each failed publication in a different private directory.
                if self.destination.exists():
                    import shutil
                    shutil.rmtree(self.destination)
                self.commands.clear()
                self.sealed = False
                self.created[4] = 'off'

                def fail(arguments):
                    operation = ('copy' if arguments[0] == 'rsync' else 'flush' if arguments[0] == 'zpool'
                                 else 'seal' if arguments[1] == 'set' else arguments[1])
                    if operation == failure:
                        self.commands.append(arguments)
                        raise subprocess.CalledProcessError(1, arguments, stderr='PRIVATE NATIVE DIAGNOSTIC')
                    return self.command(arguments)

                with self.assertRaises(subprocess.CalledProcessError):
                    self.publish(command=fail)
                self.assertTrue(self.destination.is_dir())
                self.assertFalse(any('destroy' in args or 'promote' in args for args in self.commands))
                self.assertFalse(self.sealed)

    def test_unsafe_parent_permissions_refuse_before_reservation(self):
        self.parent.chmod(0o755)
        with self.assertRaises(ValueError):
            self.publish()
        self.assertFalse(self.destination.exists())

    def test_source_mutation_after_copy_refuses_before_seal(self):
        def mutate(arguments):
            result = self.command(arguments)
            if arguments[0] == 'rsync':
                (self.source / 'etc/config').write_bytes(b'mutated fixture')
            return result
        with self.assertRaises(ValueError):
            self.publish(command=mutate)
        self.assertFalse(self.sealed)
        self.assertTrue(self.destination.exists())

    def test_copy_corruption_refuses_after_seal_and_is_retained(self):
        def corrupt(arguments):
            result = self.command(arguments)
            if arguments[0] == 'rsync':
                (self.destination / 'etc/config').write_bytes(b'corrupt fixture')
            return result
        with self.assertRaises(ValueError):
            self.publish(command=corrupt)
        self.assertTrue(self.sealed)
        self.assertTrue(self.destination.exists())

    def test_changed_source_or_parent_native_identity_refuses(self):
        for which in ['source', 'parent', 'destination']:
            calls = 0

            def changed(path, readonly, guid=None, parent=False):
                nonlocal calls
                row = self.filesystem(path, readonly, guid, parent)
                target = self.source if which == 'source' else self.parent if which == 'parent' else self.destination
                if path == target:
                    calls += 1
                    if calls > 1:
                        row[1] = '999'
                return row

            with self.subTest(which=which), self.assertRaises(ValueError):
                self.publish(filesystem=changed)
            if self.destination.exists():
                import shutil
                shutil.rmtree(self.destination)
            self.sealed = False
            self.created[4] = 'off'

    def test_malformed_inputs_and_live_root_refuse_before_commands(self):
        for index, value in [(0, '/'), (0, str(self.releases)), (1, '../host'), (2, 'release\n'),
                             (3, '0'), (4, 'sha256:' + 'a' * 64 + '\n')]:
            original = list(self.args)
            self.args[index] = value
            with self.subTest(index=index), self.assertRaises(ValueError):
                self.publish()
            self.args = original
            self.assertFalse(self.destination.exists())
        self.assertEqual(self.commands, [])

    def test_native_filesystem_admission(self):
        output = '\t'.join(self.source_row) + '\n'
        mountinfo = '10 1 0:1 / ' + str(self.source) + ' ro - zfs pool/offline ro\n'
        with patch.object(PUB, 'command', return_value=output), \
                patch.object(Path, 'read_text', return_value=mountinfo), patch.object(PUB.ROOT, 'safe_ancestors'):
            self.assertEqual(PUB.filesystem(self.source, 'on', '456'), self.source_row)
            for readonly, guid in [('off', '456'), ('on', '999')]:
                with self.assertRaises(ValueError):
                    PUB.filesystem(self.source, readonly, guid)
        for bad_output, bad_mount in [(output.replace('\ton\n', '\toff\n'), mountinfo),
                                      (output, mountinfo.replace(' - zfs ', ' - nfs ')),
                                      (output, mountinfo * 2),
                                      (output + output.replace('pool/offline', 'pool/offline/child').replace(str(self.source), str(self.source / 'child')), mountinfo),
                                      (output, mountinfo + mountinfo.replace(str(self.source), str(self.source / 'child')))]:
            with patch.object(PUB, 'command', return_value=bad_output), \
                    patch.object(Path, 'read_text', return_value=bad_mount), \
                    patch.object(PUB.ROOT, 'safe_ancestors'), self.assertRaises(ValueError):
                PUB.filesystem(self.source, 'on')

    def test_cli_failure_is_sanitized_and_no_stdout(self):
        result = subprocess.run(['python3', str(PROJECT / 'files/build/publish-stage3-root.py'), *self.args],
                                capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, '')
        self.assertEqual(result.stderr, 'Stage 3 root publication failed; retain reserved paths for diagnosis; no accepted artifact emitted\n')


if __name__ == '__main__':
    unittest.main()
