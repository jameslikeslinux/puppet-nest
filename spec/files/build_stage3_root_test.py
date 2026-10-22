#!/usr/bin/env python3
"""Filesystem and native-command fixtures; never create or modify ZFS datasets."""

import importlib.util
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import unittest
from unittest.mock import patch

PROJECT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('stage3_root', PROJECT / 'files/build/check-stage3-root.py')
assert SPEC is not None and SPEC.loader is not None
ROOT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ROOT)


class RootTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.root = self.base / 'release-one/hosts/fixture-host'
        self.root.mkdir(parents=True)
        (self.root / 'etc').mkdir()
        (self.root / 'etc/config').write_bytes(b'fixture only\n')
        self.args = [str(self.root), 'fixture-host', 'release-one', '123', 'sha256:' + 'a' * 64]
        self.row = ['pool/releases/one', '123', str(self.root), 'yes', 'on', 'release-one', self.args[4]]
        self.mountinfo = '10 1 0:1 / ' + str(self.root) + ' ro - zfs pool/releases/one ro\n'

    def check(self, **kwargs):
        with patch.object(ROOT, 'BASE', self.base), patch.object(ROOT, 'safe_ancestors'), \
                patch.object(ROOT, 'observe', return_value=self.row):
            return ROOT.check(*self.args, **kwargs)

    def observe(self, rows=None, mounts=None):
        output = '\n'.join('\t'.join(row) for row in (rows if rows is not None else [self.row])) + '\n'
        with patch.object(ROOT.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, output, '')) as command, \
                patch.object(Path, 'read_text', return_value=self.mountinfo if mounts is None else mounts):
            observed = ROOT.observe(self.root, self.args[3], self.args[2], self.args[4])
        self.assertEqual(command.call_args.args[0][0:2], ['zfs', 'list'])
        return observed

    def test_success_emits_only_exact_root_contract_and_rechecks(self):
        with patch.object(ROOT, 'BASE', self.base), patch.object(ROOT, 'safe_ancestors') as paths, \
                patch.object(ROOT, 'observe', return_value=self.row) as observe:
            row = ROOT.check(*self.args)
        self.assertEqual(set(row), {'path', 'dataset_guid', 'content_digest'})
        self.assertEqual(row['path'], str(self.root))
        self.assertEqual(row['dataset_guid'], '123')
        self.assertEqual(paths.call_count, 2)
        self.assertEqual(observe.call_count, 2)
        self.assertEqual(row, self.check(expected_digest=row['content_digest']))

    def test_changed_digest_refuses(self):
        with self.assertRaises(ValueError):
            self.check(expected_digest='sha256:' + 'b' * 64)

    def test_unsafe_tokens_and_alias_paths_refuse_before_commands(self):
        for index, value in [(0, '/nest/hosts/fixture-host'), (0, str(self.root) + '/'),
                             (1, 'fixture-host\n'), (2, '../one'), (2, 'release-one\n'),
                             (3, '0'), (3, '123\n'), (4, 'sha256:' + 'a' * 64 + '\n')]:
            args = list(self.args)
            args[index] = value
            with self.subTest(index=index, value=value), patch.object(ROOT, 'BASE', self.base), \
                    patch.object(ROOT, 'observe') as observe, self.assertRaises(ValueError):
                ROOT.check(*args)
            observe.assert_not_called()

    def test_missing_or_symlink_ancestor_refuses(self):
        with self.assertRaises((ValueError, OSError)):
            ROOT.safe_ancestors(self.root / 'absent')
        link = self.base / 'alias'
        link.symlink_to(self.root, target_is_directory=True)
        with self.assertRaises(ValueError):
            ROOT.safe_ancestors(link)

    def test_mount_and_exact_seal_properties_pass(self):
        self.assertEqual(self.observe(), self.row)

    def test_missing_changed_writable_unmounted_or_wrong_release_refuses(self):
        cases = [[]]
        for index, value in [(1, '124'), (3, 'no'), (4, 'off'), (5, 'older'), (6, 'sha256:' + 'b' * 64)]:
            row = list(self.row)
            row[index] = value
            cases.append([row])
        for rows in cases:
            with self.subTest(rows=rows), self.assertRaises(ValueError):
                self.observe(rows=rows)

    def test_duplicate_path_and_descendant_dataset_refuse(self):
        child = list(self.row)
        child[0] += '/child'
        child[2] += '/child'
        for rows in [[self.row, self.row], [self.row, child]]:
            with self.assertRaises(ValueError):
                self.observe(rows=rows)

    def test_submount_stacked_mount_and_wrong_filesystem_refuse(self):
        child = self.mountinfo.replace(str(self.root), str(self.root / 'etc'))
        for mounts in ['', self.mountinfo + child, self.mountinfo * 2,
                       self.mountinfo.replace(' - zfs ', ' - nfs '),
                       self.mountinfo.replace('pool/releases/one', 'pool/other')]:
            with self.subTest(mounts=mounts), self.assertRaises(ValueError):
                self.observe(mounts=mounts)

    def test_native_failure_and_timeout_propagate(self):
        for error in [subprocess.CalledProcessError(1, ['zfs']), subprocess.TimeoutExpired(['zfs'], 30)]:
            with patch.object(ROOT.subprocess, 'run', side_effect=error), self.assertRaises(type(error)):
                ROOT.observe(self.root, self.args[3], self.args[2], self.args[4])

    def test_changed_seal_after_scan_refuses(self):
        with patch.object(ROOT, 'BASE', self.base), patch.object(ROOT, 'safe_ancestors'), \
                patch.object(ROOT, 'observe', side_effect=[self.row, ['different']]), self.assertRaises(ValueError):
            ROOT.check(*self.args)

    def test_stable_read_does_not_modify_files(self):
        path = self.root / 'etc/config'
        before = ROOT.metadata(path.lstat())
        first = ROOT.content_digest(self.root)
        self.assertEqual(first, ROOT.content_digest(self.root))
        self.assertEqual(before, ROOT.metadata(path.lstat()))
        self.assertEqual(path.read_bytes(), b'fixture only\n')

    def test_same_size_content_change_and_permissions_change_digest(self):
        path = self.root / 'etc/config'
        first = ROOT.content_digest(self.root)
        info = path.stat()
        path.write_bytes(b'Fixture only\n')
        os.utime(path, ns=(info.st_atime_ns, info.st_mtime_ns))
        second = ROOT.content_digest(self.root)
        self.assertNotEqual(first, second)
        path.chmod(0o600)
        self.assertNotEqual(second, ROOT.content_digest(self.root))

    def test_symlink_target_is_not_followed_and_is_bound(self):
        link = self.root / 'outside'
        link.symlink_to('/this/does/not/exist')
        first = ROOT.content_digest(self.root)
        link.unlink()
        link.symlink_to('/another/missing/target')
        self.assertNotEqual(first, ROOT.content_digest(self.root))

    def test_hardlink_topology_is_bound(self):
        path = self.root / 'etc/config'
        link = self.root / 'etc/copy'
        os.link(path, link)
        first = ROOT.content_digest(self.root)
        info = link.stat()
        link.unlink()
        link.write_bytes(path.read_bytes())
        os.utime(link, ns=(info.st_atime_ns, info.st_mtime_ns))
        self.assertNotEqual(first, ROOT.content_digest(self.root))

    def test_xattrs_are_bound(self):
        path = self.root / 'etc/config'
        first = ROOT.content_digest(self.root)
        os.setxattr(path, 'user.fixture', b'only synthetic bytes')
        self.assertNotEqual(first, ROOT.content_digest(self.root))

    def test_fifo_supported_without_opening_it(self):
        os.mkfifo(self.root / 'fifo')
        self.assertRegex(ROOT.content_digest(self.root), '^sha256:[0-9a-f]{64}$')

    def test_socket_refuses(self):
        with socket.socket(socket.AF_UNIX) as sock:
            sock.bind(str(self.root / 'socket'))
            with self.assertRaises(ValueError):
                ROOT.content_digest(self.root)

    def test_observed_mutation_during_read_refuses(self):
        # Mutate after xattr observation but before descriptor admission.
        actual = ROOT.os.open

        def changed(path, flags):
            if Path(path).name == 'config':
                Path(path).write_bytes(b'mutation')
            return actual(path, flags)

        with patch.object(ROOT.os, 'open', side_effect=changed), self.assertRaises(ValueError):
            ROOT.content_digest(self.root)

    def test_cli_error_does_not_echo_private_diagnostics(self):
        result = subprocess.run(['python3', str(PROJECT / 'files/build/check-stage3-root.py'), *self.args],
                                capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, '')
        self.assertEqual(result.stderr, 'Stage 3 root admission failed; no accepted root artifact emitted\n')


if __name__ == '__main__':
    unittest.main()
