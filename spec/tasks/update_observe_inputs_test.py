#!/usr/bin/env python3
"""Offline exact observation commands; never invoke a host command."""

import copy
import json
from pathlib import Path
import subprocess
import sys
import unittest

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tasks'))
from update_observe_inputs import observe
from update_wave_plan_test import policy


class ObserveInputsTest(unittest.TestCase):
    def setUp(self):
        self.policy = policy()
        self.targets = [host['name'] for host in self.policy['hosts']]
        self.inputs = {name: {'transaction': 'fixture-' + name} for name in self.targets}

    def test_only_stored_status_commands_and_bounded_waves(self):
        result = observe(self.policy, self.targets, self.inputs)
        self.assertEqual([len(wave) for wave in result['waves']], [1, 3, 3])
        for name, command in result['commands'].items():
            self.assertEqual(command, ['nest', 'reset', 'status', 'fixture-' + name, '--format=json'])
        self.assertEqual(result['reboot_eligible'], [])
        self.assertFalse(result['execution_authorized'])

    def test_missing_extra_or_mutating_inputs_refuse(self):
        for bad in ({}, dict(self.inputs, extra={'transaction': 'extra'}),
                    {name: row for name, row in self.inputs.items() if name != 'leaf'}):
            with self.assertRaises(ValueError):
                observe(self.policy, self.targets, bad)
        for mutation in ({'transaction': '--help'}, {'transaction': 'a;reboot'}, {'resume': True},
                         {'root_generation': '/releases/one'}, {'capacity_policy': '/etc/nest/policy.json'}):
            bad = copy.deepcopy(self.inputs)
            bad['canary'].update(mutation)
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                observe(self.policy, self.targets, bad)

    def test_complete_policy_still_required(self):
        with self.assertRaises(ValueError):
            observe(self.policy, self.targets[:-1], self.inputs)
        with self.assertRaises(ValueError):
            observe(dict(self.policy, release='latest'), self.targets, self.inputs)

    def test_real_stdin_duplicate_keys_bounds_and_private_error(self):
        args = [sys.executable, str(ROOT / 'tasks/update_observe_inputs.py')]
        payload = {'policy': self.policy, 'targets': self.targets, 'inputs': self.inputs}
        result = subprocess.run(args, input=json.dumps(payload), text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertEqual(json.loads(result.stdout)['inputs'], self.inputs)
        for raw in ('{"inputs":{},"inputs":{"private":"sentinel"}}', 'x' * 262145, '[]'):
            result = subprocess.run(args, input=raw, text=True, capture_output=True, check=False)
            self.assertEqual(result.returncode, 1)
            self.assertNotIn('sentinel', result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
