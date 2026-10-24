#!/usr/bin/env python3
"""Disposable supervisor retention; no live archive, backup host or reset."""

import hashlib
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tasks'))
from retain_update_backup import binding, project
from retain_update_report import publish_document


def fixture(directory):
    check = dict(kind='hermes', target='fixture-backup', user='joy', backup_dir='/private/fixture',
                 checkpoint='fixture', expected_sha256='c' * 64, max_age_seconds=3600, required_profiles=['talon'])
    retention = dict(transaction='fixture', release='sha256:' + 'a' * 64, hostname='fixture-host',
                     policy_sha256='b' * 64, stage='preflight', output_dir=str(directory))
    row = dict(schema=1, kind='nest_hermes_generation_verification', action='verified', checkpoint='fixture',
               sha256='c' * 64, archive='hermes-home-fixture.zip', bytes=1234, members=12, required_profiles=['talon'],
               created_at='2026-10-24T12:00:00Z', checked_at='2026-10-24T12:01:00Z', max_age_seconds=3600,
               restore_verified=False, execution_authorized=False, private='private-sentinel')
    return check, retention, row


class RetentionTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.check, self.retention, self.row = fixture(self.directory)

    def project(self, row=None):
        return project(json.dumps(self.row if row is None else row), self.check, self.retention)

    def test_projection_preserves_binding_without_private_paths_or_restore_claim(self):
        result = self.project()
        for key in ('transaction', 'release', 'hostname', 'policy_sha256', 'stage'):
            self.assertEqual(result[key], self.retention[key])
        self.assertEqual(result['backup_target'], self.check['target'])
        self.assertNotIn('private-sentinel', json.dumps(result))
        self.assertNotIn('/private/fixture', json.dumps(result))
        self.assertFalse(result['retention_lease'])
        self.assertFalse(result['restore_verified'])
        self.assertFalse(result['execution_authorized'])

    def test_atomic_publication_reopens_and_identical_repeat_is_idempotent(self):
        result = self.project()
        first = publish_document(result, self.directory, 'fixture-backup')
        self.assertEqual(first, publish_document(result, self.directory, 'fixture-backup'))
        raw = Path(first['path']).read_bytes()
        self.assertTrue(first['readback_verified'])
        self.assertEqual(first['sha256'], hashlib.sha256(raw).hexdigest())
        self.assertEqual(first['bytes'], len(raw))
        self.assertEqual(json.loads(raw), result)
        self.assertEqual(len(list(self.directory.iterdir())), 1)

    def test_refuses_wrong_generation_requirements_and_authority(self):
        changes = dict(schema=True, kind='wrong', action='created', checkpoint='other', sha256='d' * 64,
                       archive='elsewhere.zip', required_profiles=[], max_age_seconds=True,
                       restore_verified=True, execution_authorized=True, bytes=True, members=0)
        for key, value in changes.items():
            with self.subTest(key=key):
                row = dict(self.row, **{key: value})
                with self.assertRaises(ValueError):
                    self.project(row)

    def test_refuses_inconsistent_or_invalid_timestamps(self):
        for created, checked in [('2026-10-24T12:02:00Z', '2026-10-24T12:01:00Z'),
                                 ('2026-10-24T10:00:00Z', '2026-10-24T12:01:00Z'),
                                 ('2026-02-30T12:00:00Z', '2026-10-24T12:01:00Z'),
                                 ('2026-10-24T12:00:00+00:00', '2026-10-24T12:01:00Z')]:
            with self.subTest(created=created):
                with self.assertRaises(ValueError):
                    self.project(dict(self.row, created_at=created, checked_at=checked))

    def test_rejects_duplicate_json_keys_and_oversized_output(self):
        for raw in [json.dumps(self.row)[:-1] + ', "action": "verified"}', ' ' * 65537]:
            with self.assertRaises(ValueError):
                project(raw, self.check, self.retention)

    def test_binding_refuses_missing_unknown_or_changed_scope_fields(self):
        for key in self.retention:
            retention = dict(self.retention)
            del retention[key]
            with self.subTest(key=key):
                with self.assertRaises((KeyError, ValueError)):
                    binding(self.check, retention)
        for change in [dict(stage='accept'), dict(release='main'), dict(extra=True)]:
            retention = dict(self.retention, **change)
            with self.assertRaises(ValueError):
                binding(self.check, retention)

    def test_requirement_digest_changes_with_placement(self):
        first = self.project()['requirement_sha256']
        self.check['backup_dir'] = '/private/other'
        self.assertNotEqual(first, self.project()['requirement_sha256'])

    def test_preflight_and_initiation_preserve_separate_observations(self):
        first = publish_document(self.project(), self.directory, 'fixture-backup-preflight')
        self.retention['stage'] = 'initiation'
        second = publish_document(self.project(), self.directory, 'fixture-backup-initiation')
        self.assertNotEqual(first['path'], second['path'])
        self.assertEqual(len(list(self.directory.iterdir())), 2)

    def test_bad_destination_refuses_without_creating_it(self):
        self.retention['output_dir'] = str(self.directory / 'missing')
        with self.assertRaises(OSError):
            self.project()
        self.assertEqual(list(self.directory.iterdir()), [])

    def test_conflicting_retained_target_is_not_replaced(self):
        first = publish_document(self.project(), self.directory, 'fixture-backup')
        path = Path(first['path'])
        path.write_text('original diagnostic bytes')
        with self.assertRaises(ValueError):
            publish_document(self.project(), self.directory, 'fixture-backup')
        self.assertEqual(path.read_text(), 'original diagnostic bytes')

    def test_native_task_errors_are_generic_and_never_publish_private_output(self):
        task = Path(__file__).resolve().parents[2] / 'tasks/retain_update_backup.py'
        for report in ['private-sentinel', json.dumps(dict(self.row, checkpoint='wrong'))]:
            params = dict(check=self.check, retention=self.retention, report=report)
            run = subprocess.run([sys.executable, str(task)], input=json.dumps(params), capture_output=True, text=True)
            self.assertEqual(run.returncode, 1)
            self.assertEqual(json.loads(run.stdout)['_error']['kind'], 'nest/update-backup-retention')
            self.assertNotIn('private-sentinel', run.stdout + run.stderr)
            self.assertEqual(list(self.directory.iterdir()), [])

    def test_check_task_creates_no_file_or_lock(self):
        task = Path(__file__).resolve().parents[2] / 'tasks/retain_update_backup.py'
        params = dict(action='check', check=self.check, retention=self.retention)
        run = subprocess.run([sys.executable, str(task)], input=json.dumps(params), capture_output=True, text=True)
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertTrue(json.loads(run.stdout)['destination_checked'])
        self.assertEqual(list(self.directory.iterdir()), [])


    def hold_observation(self):
        self.check['hold_id'] = 'release-fixture'
        hold = {key: self.row[key] for key in ('checkpoint', 'archive', 'sha256', 'bytes', 'members', 'required_profiles')}
        hold.update(schema=1, kind='nest_hermes_generation_hold', hold_id='release-fixture', release=self.retention['release'])
        return dict(schema=1, kind='nest_hermes_generation_retention', action='check-hold', hold=hold,
                    held=True, readback_verified=True, restore_verified=False, execution_authorized=False,
                    verification=self.row, private='private-sentinel')

    def test_exact_hold_and_verification_are_retained_together(self):
        row = self.hold_observation()
        result = self.project(row)
        self.assertTrue(result['hold_checked'])
        self.assertEqual(result['hold'], row['hold'])
        self.assertNotIn('private-sentinel', json.dumps(result))
        task = Path(__file__).resolve().parents[2] / 'tasks/retain_update_backup.py'
        params = dict(check=self.check, retention=self.retention, report=json.dumps(row))
        run = subprocess.run([sys.executable, str(task)], input=json.dumps(params), capture_output=True, text=True)
        self.assertEqual(run.returncode, 0, run.stderr)
        receipt = json.loads(run.stdout)
        self.assertTrue(receipt['hold_checked'])
        self.assertEqual(json.loads(Path(receipt['path']).read_text()), result)

    def test_plain_verification_cannot_satisfy_hold_requirement(self):
        self.hold_observation()
        with self.assertRaises(ValueError):
            self.project()

    def test_hold_refuses_wrong_action_identity_counts_coverage_or_authority(self):
        original = self.hold_observation()
        changes = dict(schema=True, kind='wrong', action='hold', held=False, readback_verified=False,
                       restore_verified=True, execution_authorized=True, verification=None)
        for key, value in changes.items():
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.project(dict(original, **{key: value}))
        changes = dict(schema=True, kind='wrong', hold_id='other', release='sha256:' + 'd' * 64,
                       checkpoint='wrong', archive='wrong.zip', sha256='d' * 64, bytes=True, members=0,
                       required_profiles=['star'], extra=True)
        for key, value in changes.items():
            row = copy.deepcopy(original)
            row['hold'][key] = value
            with self.subTest(hold_key=key), self.assertRaises(ValueError):
                self.project(row)


if __name__ == '__main__':
    unittest.main()
