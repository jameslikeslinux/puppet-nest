#!/usr/bin/env python3
"""Offline native preparation input contracts; never execute a reset."""

import copy
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import subprocess
import sys
import unittest

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tasks'))
from update_prepare_inputs import prepare
from update_wave_plan_test import policy


def inputs(selected):
    return {name: {'transaction': 'fixture-' + name, 'root_generation': '/releases/fixture',
                   'capacity_policy': '/etc/nest/fixture-capacity.json',
                   'generation_policy': {'hostname': name, 'release': 'sha256:' + 'b' * 64,
                                         'destination': '/releases/fixture'}} for name in selected}


def preparation_policy():
    value = policy()
    now = datetime.now(timezone.utc)
    value['schema'] = 3
    value['backup_requirements'] = {host['name']: [] for host in value['hosts']}
    value['preparation_window'] = {
        'not_before': (now - timedelta(minutes=1)).strftime('%Y-%m-%dT%H:%M:%SZ'),
        'not_after': (now + timedelta(hours=1)).strftime('%Y-%m-%dT%H:%M:%SZ'),
    }
    return value


class PrepareInputsTest(unittest.TestCase):
    def setUp(self):
        self.policy = preparation_policy()
        self.targets = [host['name'] for host in self.policy['hosts']]
        self.inputs = inputs(self.targets)

    def test_native_once_commands_preserve_bounded_waves(self):
        result = prepare(self.policy, self.targets, self.inputs)
        self.assertEqual(result['waves'], [['canary'], ['core-a', 'joined-a', 'leaf'], ['core-b', 'usb-child', 'joined-b']])
        for name, argv in result['commands'].items():
            self.assertEqual(argv, ['nest', 'reset', '--transaction', 'fixture-' + name,
                                   '--release', self.policy['release'], '--root-generation', '/releases/fixture',
                                   '--capacity-policy', '/etc/nest/fixture-capacity.json', '--format=json'])
            self.assertNotIn('--resume', argv)
            self.assertNotIn('--resume-transaction', argv)
        self.assertFalse(result['execution_authorized'])
        self.assertEqual(result['reboot_eligible'], [])

    def test_complete_inputs_required_before_any_command(self):
        for bad in ({}, dict(self.inputs, extra=self.inputs['canary']), {key: value for key, value in self.inputs.items() if key != 'leaf'}):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                prepare(self.policy, self.targets, bad)

    def test_seal_must_bind_same_host_release_and_native_root(self):
        for change in ({'hostname': 'other'}, {'release': 'sha256:' + 'c' * 64},
                       {'destination': '/other/root'}):
            value = copy.deepcopy(self.inputs)
            value['canary']['generation_policy'].update(change)
            with self.subTest(change=change), self.assertRaises(ValueError):
                prepare(self.policy, self.targets, value)
        for bad in (None, [], {}):
            value = copy.deepcopy(self.inputs)
            value['canary']['generation_policy'] = bad
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                prepare(self.policy, self.targets, value)
        value = copy.deepcopy(self.inputs)
        del value['leaf']['generation_policy']
        with self.assertRaises(ValueError):
            prepare(self.policy, self.targets, value)

    def test_every_preparation_byte_is_bound_even_when_command_is_unchanged(self):
        first = prepare(self.policy, self.targets, self.inputs)
        value = copy.deepcopy(self.inputs)
        value['canary']['generation_policy']['destination_guid'] = '123'
        changed = prepare(self.policy, self.targets, value)
        self.assertEqual(first['commands'], changed['commands'])
        self.assertNotEqual(first['inputs_sha256'], changed['inputs_sha256'])

    def test_unknown_keys_and_unsafe_paths_refuse(self):
        mutations = [{'resume': True}, {'transaction': '--help'}, {'transaction': 'x; reboot'},
                     {'root_generation': '/nest/hosts/canary'}, {'root_generation': '/a/../b'},
                     {'root_generation': '/'}, {'root_generation': '/a//b'}, {'root_generation': '/a/'},
                     {'capacity_policy': '/a/./b'}, {'capacity_policy': '/a;reboot'}, {'capacity_policy': '-f'}]
        for mutation in mutations:
            value = copy.deepcopy(self.inputs)
            value['canary'].update(mutation)
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                prepare(self.policy, self.targets, value)

    def test_wrong_inventory_release_or_console_refuses(self):
        for key, value in [('release', 'latest'), ('config_source', 'main')]:
            candidate = dict(self.policy, **{key: value})
            with self.assertRaises(ValueError):
                prepare(candidate, self.targets, self.inputs)
        with self.assertRaises(ValueError):
            prepare(self.policy, self.targets[:-1], self.inputs)

    def test_real_stdin_and_duplicate_private_input(self):
        task = ROOT / 'tasks/update_prepare_inputs.py'
        payload = {'policy': self.policy, 'targets': self.targets, 'inputs': self.inputs}
        result = subprocess.run([sys.executable, str(task)], input=json.dumps(payload), text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertEqual(json.loads(result.stdout)['inputs'], self.inputs)
        for raw in ('{"inputs":{},"inputs":{"private":"sentinel"}}', 'x' * 262145, '[]'):
            result = subprocess.run([sys.executable, str(task)], input=raw, text=True, capture_output=True, check=False)
            self.assertEqual(result.returncode, 1)
            self.assertNotIn('sentinel', result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
