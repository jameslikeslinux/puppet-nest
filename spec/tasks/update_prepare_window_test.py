#!/usr/bin/env python3
"""Preparation windows are enforced without issuing any host command."""

import copy
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tasks'))
from update_prepare_inputs import prepare
from update_observe_inputs import observe
from update_wave_plan import plan
from update_wave_plan_test import policy
from update_prepare_inputs_test import inputs


def bounded_policy():
    value = policy()
    value['schema'] = 2
    value['preparation_window'] = {'not_before': '2030-01-01T00:00:00Z', 'not_after': '2030-01-01T01:00:00Z'}
    return value


class PrepareWindowTest(unittest.TestCase):
    def setUp(self):
        self.policy = bounded_policy()
        self.targets = [host['name'] for host in self.policy['hosts']]
        self.inputs = inputs(self.targets)

    def at(self, timestamp):
        return patch('update_prepare_inputs.current_time', return_value=datetime.fromisoformat(timestamp.replace('Z', '+00:00')))

    def test_unbounded_legacy_policy_can_plan_and_observe_but_never_prepare(self):
        legacy = policy()
        self.assertEqual(plan(legacy, self.targets)['waves'][0], ['canary'])
        statuses = {name: {'transaction': entry['transaction']} for name, entry in self.inputs.items()}
        self.assertEqual(observe(legacy, self.targets, statuses)['commands']['canary'][2], 'status')
        with self.assertRaises(ValueError):
            prepare(legacy, self.targets, self.inputs)

    def test_start_inclusive_end_exclusive_and_no_cached_admission(self):
        for timestamp, allowed in [('2029-12-31T23:59:59Z', False), ('2030-01-01T00:00:00Z', True),
                                   ('2030-01-01T00:59:59Z', True), ('2030-01-01T01:00:00Z', False)]:
            with self.subTest(timestamp=timestamp), self.at(timestamp):
                if allowed:
                    result = prepare(self.policy, self.targets, self.inputs)
                    self.assertFalse(result['execution_authorized'])
                    self.assertEqual(result['reboot_eligible'], [])
                    self.assertEqual(result['preparation_window'], self.policy['preparation_window'])
                else:
                    with self.assertRaises(ValueError):
                        prepare(self.policy, self.targets, self.inputs)

    def test_planning_and_status_are_available_outside_window(self):
        self.assertEqual(plan(self.policy, self.targets)['policy_schema'], 2)
        statuses = {name: {'transaction': entry['transaction']} for name, entry in self.inputs.items()}
        self.assertEqual(observe(self.policy, self.targets, statuses)['commands']['canary'][2], 'status')

    def test_strict_utc_seconds_real_calendar_and_bounded_duration(self):
        invalid = [None, {}, {'not_before': '2030-01-01T00:00:00Z'},
                   {'not_before': '2030-01-01T00:00:00Z', 'not_after': '2030-01-01T01:00:00Z', 'approved': True}]
        for start, end in [('2030-01-01T00:00:00+00:00', '2030-01-01T01:00:00Z'),
                           ('2030-01-01T00:00:00.0Z', '2030-01-01T01:00:00Z'),
                           ('2030-02-30T00:00:00Z', '2030-03-01T01:00:00Z'),
                           ('2030-01-01T00:00:00Z', '2030-01-01T00:00:00Z'),
                           ('2030-01-01T01:00:00Z', '2030-01-01T00:00:00Z'),
                           ('2030-01-01T00:00:00Z', '2030-01-02T00:00:01Z'),
                           (True, '2030-01-01T01:00:00Z')]:
            invalid.append({'not_before': start, 'not_after': end})
        for window in invalid:
            candidate = dict(self.policy, preparation_window=window)
            with self.subTest(window=window), self.assertRaises(ValueError):
                plan(candidate, self.targets)
        candidate = copy.deepcopy(self.policy)
        candidate['preparation_window']['not_after'] = '2030-01-02T00:00:00Z'
        self.assertEqual(plan(candidate, self.targets)['policy_schema'], 2)

    def test_every_window_byte_is_bound_to_policy_digest(self):
        first = plan(self.policy, self.targets)['policy_sha256']
        candidate = copy.deepcopy(self.policy)
        candidate['preparation_window']['not_after'] = '2030-01-01T02:00:00Z'
        self.assertNotEqual(plan(candidate, self.targets)['policy_sha256'], first)
        legacy = dict(self.policy, schema=1)
        with self.assertRaises(ValueError):
            plan(legacy, self.targets)

    def test_real_stdin_rejects_expired_policy_without_exposing_input(self):
        candidate = copy.deepcopy(self.policy)
        candidate['preparation_window'] = {'not_before': '2000-01-01T00:00:00Z', 'not_after': '2000-01-01T01:00:00Z'}
        payload = {'policy': candidate, 'targets': self.targets, 'inputs': self.inputs}
        result = subprocess.run([sys.executable, str(ROOT / 'tasks/update_prepare_inputs.py')],
                                input=json.dumps(payload), text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 1)
        self.assertNotIn('fixture-capacity', result.stdout + result.stderr)
        self.assertEqual(json.loads(result.stdout)['_error']['kind'], 'nest/update-prepare-inputs')


if __name__ == '__main__':
    unittest.main()
