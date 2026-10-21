"""Fault fixtures: commands are fake, filesystem effects use disposable directories."""

import importlib.machinery
import importlib.util
import json
from pathlib import Path
import stat
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock


sys.dont_write_bytecode = True
HELPER = Path(__file__).resolve().parents[2] / 'files/nest-update-state'
loader = importlib.machinery.SourceFileLoader('update_state', str(HELPER))
spec = importlib.util.spec_from_loader(loader.name, loader)
assert spec is not None
state = importlib.util.module_from_spec(spec)
loader.exec_module(state)
MACHINE = 'a' * 32


class StateTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / 'nest/updates'
        self.dataset = 'owl/crypt/nest-updates'
        self.rows = [{'source': 'owl/crypt/ROOT/B', 'target': '/', 'fstype': 'zfs', 'options': 'rw'}]
        self.props = {}
        self.binding = '-'
        self.calls = []
        for patcher in (mock.patch.object(state, 'STATE', self.path),
                        mock.patch.object(state, 'secure_directory'),
                        mock.patch.object(state.Path, 'read_text', return_value=MACHINE),
                        mock.patch.object(state, 'run', side_effect=self.command)):
            patcher.start()
            self.addCleanup(patcher.stop)

    def command(self, *args):
        self.calls.append(args)
        if args[0] == '/bin/findmnt':
            return json.dumps({'filesystems': self.rows})
        if args[:2] == ('/sbin/zpool', 'get'):
            return self.binding
        if args[:2] == ('/sbin/zfs', 'get'):
            return '\n'.join('\t'.join((self.dataset, key, value)) for key, value in self.props.items())
        if args[:2] == ('/sbin/zfs', 'create'):
            self.props = dict(type='filesystem', mountpoint=str(self.path), canmount='noauto', readonly='off')
            self.props[state.OWNER] = MACHINE
            return ''
        if args[:2] == ('/sbin/zpool', 'set'):
            self.binding = MACHINE
            return ''
        if args[:2] == ('/sbin/zfs', 'mount'):
            self.rows.append(dict(source=self.dataset, target=str(self.path), fstype='zfs', options='rw,relatime'))
            return ''
        raise AssertionError(args)

    def writes(self):
        return [args for args in self.calls if args[1] in ('create', 'set', 'mount')]

    def test_create_mount_and_idempotent_repeat(self):
        self.assertEqual(state.ensure(), self.dataset)
        self.assertEqual([args[1] for args in self.writes()], ['create', 'set', 'mount'])
        self.assertEqual(stat.S_IMODE(self.path.stat().st_mode), 0o700)
        self.calls.clear()
        state.ensure()
        self.assertFalse(self.writes())

    def test_read_only_missing_state_creates_nothing(self):
        self.assertFalse(state.inspect()[-1])
        self.assertFalse(self.path.parent.exists())
        self.assertFalse(self.writes())

    def test_pool_binding_mismatch_refuses_without_change(self):
        self.binding = 'b' * 32
        with self.assertRaisesRegex(RuntimeError, 'another host'):
            state.ensure()
        self.assertFalse(self.writes())

    def test_non_zfs_and_stacked_roots_refuse(self):
        for roots in ([dict(self.rows[0], fstype='nfs')], self.rows * 2):
            with self.subTest(roots=roots), self.assertRaises(RuntimeError):
                state.topology(roots)
        self.assertFalse(self.writes())

    def test_bad_root_layout_refuses(self):
        for name in ('owl/ROOT/A/var', 'owl/ROOT/ROOT/B', 'owl/not-a-be', 'nfs:/ROOT/A'):
            # A colon is not valid in a ZFS pool name; refuse pseudo-local sources.
            with self.subTest(name=name), self.assertRaises(RuntimeError):
                state.topology([dict(self.rows[0], source=name)])

    def test_existing_per_be_receipt_is_not_hidden(self):
        self.path.mkdir(parents=True)
        receipt = self.path / 'previous.json'
        receipt.write_text('preserve')
        with self.assertRaisesRegex(RuntimeError, 'hide existing'):
            state.ensure()
        self.assertEqual(receipt.read_bytes(), b'preserve')
        self.assertFalse(self.writes())

    def test_existing_unowned_dataset_refuses(self):
        self.props = {'type': 'filesystem', 'mountpoint': str(self.path)}
        with self.assertRaisesRegex(RuntimeError, 'managed state contract'):
            state.ensure()
        self.assertFalse(self.writes())

    def test_alien_mount_and_descendant_refuse(self):
        for mount in (dict(source='server:/state', target=str(self.path), fstype='nfs', options='rw'),
                      dict(source='other', target=str(self.path) + '/child', fstype='zfs', options='rw')):
            self.rows.append(mount)
            with self.assertRaises(RuntimeError):
                state.ensure()
            self.rows.pop()
        self.assertFalse(self.writes())

    def test_readonly_or_changed_property_never_repaired(self):
        state.ensure()
        self.calls.clear()
        for key, value in (('readonly', 'on'), ('canmount', 'on'), (state.OWNER, 'b' * 32)):
            old = self.props[key]
            self.props[key] = value
            with self.assertRaises(RuntimeError):
                state.ensure()
            self.props[key] = old
        self.assertFalse(self.writes())

    def test_interruption_after_create_resumes_without_recreating(self):
        original = self.command
        def fail(*args):
            if args[:2] == ('/sbin/zpool', 'set'):
                raise RuntimeError('injected set failure')
            return original(*args)
        with mock.patch.object(state, 'run', side_effect=fail), self.assertRaises(RuntimeError):
            state.ensure()
        self.calls.clear()
        state.ensure()
        self.assertEqual([args[1] for args in self.writes()], ['set', 'mount'])

    def test_failed_mount_stops_and_never_destroys(self):
        original = self.command
        def fail(*args):
            if args[:2] == ('/sbin/zfs', 'mount'):
                raise RuntimeError('injected mount failure')
            return original(*args)
        with mock.patch.object(state, 'run', side_effect=fail), self.assertRaises(RuntimeError):
            state.ensure()
        self.assertFalse(state.inspect()[-1])
        self.assertFalse(any('destroy' in args or 'unmount' in args for args in self.calls))

    def test_zfs_query_failure_does_not_mean_dataset_absent(self):
        original = self.command
        def fail(*args):
            if args[:2] == ('/sbin/zfs', 'get'):
                raise RuntimeError('injected query failure')
            return original(*args)
        with mock.patch.object(state, 'run', side_effect=fail), self.assertRaises(RuntimeError):
            state.ensure()
        self.assertFalse(self.writes())

    def test_secure_directory_rejects_links_owner_and_modes(self):
        # Exercise the real validator independently of root privileges on CI.
        with mock.patch.object(state, 'secure_directory', wraps=original_secure):
            for mode, uid in ((stat.S_IFLNK | 0o777, 0), (stat.S_IFDIR | 0o777, 0), (stat.S_IFDIR | 0o700, 1000)):
                path = mock.Mock()
                path.lstat.return_value = SimpleNamespace(st_mode=mode, st_uid=uid)
                with self.assertRaises(RuntimeError):
                    state.secure_directory(path)


original_secure = state.secure_directory

if __name__ == '__main__':
    unittest.main()
