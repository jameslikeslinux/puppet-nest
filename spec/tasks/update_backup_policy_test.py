#!/usr/bin/env python3
"""Backup prerequisites bind full scope without checking files or contacting hosts."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import unittest

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tasks'))
from update_wave_plan import plan
from update_prepare_inputs import prepare
from update_observe_inputs import observe
from update_prepare_inputs_test import preparation_policy, inputs


def check():
    return {'kind': 'hermes', 'target': 'fixture-backup', 'user': 'joy',
            'backup_dir': '/fixture/backups', 'checkpoint': 'fixture',
            'expected_sha256': 'c' * 64, 'max_age_seconds': 3600,
            'required_profiles': ['talon', 'star', 'beryl', 'quill'], 'hold_id': 'release-fixture'}


class BackupPolicyTest(unittest.TestCase):
    def setUp(self):
        self.policy = preparation_policy()
        self.targets = [host['name'] for host in self.policy['hosts']]
        self.inputs = inputs(self.targets)
        self.policy['backup_requirements']['canary'] = [check()]

    def test_bound_requirements_are_planned_and_passed_to_preparation_without_verification_claim(self):
        for result in (plan(self.policy, self.targets), prepare(self.policy, self.targets, self.inputs)):
            self.assertEqual(result['backup_requirements'], self.policy['backup_requirements'])
            self.assertFalse(result['execution_authorized'])
            self.assertEqual(result['reboot_eligible'], [])
            self.assertNotIn('backups_verified', result)

    def test_both_older_schemas_remain_read_only_but_cannot_prepare(self):
        for schema in (1, 2):
            candidate = copy.deepcopy(self.policy)
            candidate['schema'] = schema
            del candidate['backup_requirements']
            if schema == 1:
                del candidate['preparation_window']
            planned = plan(candidate, self.targets)
            self.assertNotIn('backup_requirements', planned)
            observed = observe(candidate, self.targets, {name: {'transaction': 'fixture'} for name in self.targets})
            self.assertEqual(observed['commands']['canary'][2], 'status')
            with self.assertRaises(ValueError):
                prepare(candidate, self.targets, self.inputs)

    def test_complete_explicit_host_map_is_required(self):
        for value in ({}, [], dict(self.policy['backup_requirements'], extra=[])):
            candidate = dict(self.policy, backup_requirements=value)
            with self.subTest(value=value), self.assertRaises(ValueError):
                plan(candidate, self.targets)
        del self.policy['backup_requirements']['leaf']
        with self.assertRaises(ValueError):
            plan(self.policy, self.targets)

    def test_every_backup_input_changes_the_policy_digest(self):
        first = plan(self.policy, self.targets)['policy_sha256']
        changes = {'target': 'other-backup', 'user': 'other', 'backup_dir': '/other/backups',
                   'checkpoint': 'next', 'expected_sha256': 'd' * 64,
                   'max_age_seconds': 1800, 'required_profiles': ['talon'], 'hold_id': 'other-hold'}
        for key, value in changes.items():
            candidate = copy.deepcopy(self.policy)
            candidate['backup_requirements']['canary'][0][key] = value
            with self.subTest(key=key):
                self.assertNotEqual(plan(candidate, self.targets)['policy_sha256'], first)

    def test_unsupported_mutating_and_malformed_checks_refuse(self):
        changes = {'kind': ['registry', 'capture'], 'target': ['all*', 'ssh://root@host', 'x; reboot'],
                   'user': ['--help', 'root;reboot'], 'backup_dir': ['/', '/a/../b', '/a//b', '/a/', 'relative'],
                   'checkpoint': ['../secret', '--help'], 'expected_sha256': ['latest', 'A' * 64, 'c' * 63],
                   'max_age_seconds': [True, 0, 604801, 1.5], 'required_profiles': [[], ['talon', 'talon'], ['../private']]}
        for key, values in changes.items():
            for value in values:
                candidate = copy.deepcopy(self.policy)
                candidate['backup_requirements']['canary'][0][key] = value
                with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                    plan(candidate, self.targets)
        for key in ('verify_only', 'quick', 'prune_only', 'cleanup_legacy', 'preserve_existing', 'stage_dir'):
            candidate = copy.deepcopy(self.policy)
            candidate['backup_requirements']['canary'][0][key] = True
            with self.subTest(key=key), self.assertRaises(ValueError):
                plan(candidate, self.targets)

    def test_duplicate_check_identity_and_unbounded_list_refuse(self):
        for value in ([check(), check()], [check()] * 9, {}, None):
            candidate = copy.deepcopy(self.policy)
            candidate['backup_requirements']['canary'] = value
            with self.subTest(value=value), self.assertRaises(ValueError):
                plan(candidate, self.targets)

    def test_real_task_stdio_and_noop_are_planning_only(self):
        payload = dict(policy=self.policy, targets=self.targets, inputs=self.inputs, _noop=True)
        result = subprocess.run([sys.executable, str(ROOT / 'tasks/update_prepare_inputs.py')],
                                input=json.dumps(payload), text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)['backup_requirements'], self.policy['backup_requirements'])
        self.assertEqual(result.stderr, '')


if __name__ == '__main__':
    unittest.main()
