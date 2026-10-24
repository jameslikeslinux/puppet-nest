"""Exercise actual stdin validation and atomic publication using synthetic reports."""

import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from typing import Any
import unittest

from retain_update_report_test import fixture

TASK = Path(__file__).resolve().parents[2] / 'tasks/retain_update_finalize.py'
BOOT = '22345678-1234-1234-1234-123456789abc'


def accepted(state='accepted'):
    data = fixture(state, 2)
    data.update(acceptance={'boot_id': BOOT}, owned_candidates=[], cleanup_receipts=[],
                snapshot_policy='retain_origins_no_reclamation_claim')
    return data


def status(state='accepted'):
    data = accepted(state)
    data['observation'] = dict(boot_id=BOOT, boot_changed=True, current=data['host']['target'],
                               next_boot=data['host']['target'], expected_target_booted=True, accepted=True)
    return data


class FinalizeTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.directory = Path(self.temporary.name).resolve()
        self.arguments = dict(transaction='fixture-report', release='sha256:' + 'a' * 64,
                              hostname='fixture-host', output_dir=str(self.directory), action='admit',
                              status=json.dumps(status()))

    def tearDown(self):
        self.temporary.cleanup()

    def run_task(self, **changes):
        arguments = dict(self.arguments, **changes)
        result = subprocess.run([sys.executable, '-B', str(TASK)], input=json.dumps(arguments), capture_output=True, text=True, check=False)
        return result.returncode, json.loads(result.stdout)

    def test_admission_reopens_sanitized_live_status(self):
        data = status()
        data['acceptance']['private'] = 'private sentinel'
        code, receipt = self.run_task(status=json.dumps(data))
        self.assertEqual(code, 0, receipt)
        raw = Path(receipt['path']).read_bytes()
        self.assertTrue(receipt['readback_verified'])
        self.assertEqual(hashlib.sha256(raw).hexdigest(), receipt['sha256'])
        self.assertEqual(len(raw), receipt['bytes'])
        self.assertNotIn(b'private sentinel', raw)
        self.assertFalse(json.loads(raw)['acceptance_independently_verified'])

    def test_preview_and_completion_have_distinct_outcomes(self):
        for state in ('accepted', 'finalizing', 'finalized'):
            data = accepted(state)
            data.update(read_only=True, cleanup='owned', candidates=[])
            code, receipt = self.run_task(action='preview', status=json.dumps(status(state)), report=json.dumps(data))
            self.assertEqual(code, 0, receipt)
            self.assertEqual(receipt['state'], state)
        code, receipt = self.run_task(action='complete', report=json.dumps(accepted('finalized')))
        self.assertEqual(code, 0, receipt)
        self.assertTrue(receipt['cli_finalized'])

    def test_check_does_not_create_files(self):
        code, result = self.run_task(action='check')
        self.assertEqual(code, 0)
        self.assertFalse(result['host_action_performed'])
        self.assertEqual(list(self.directory.iterdir()), [])

    def test_bad_context_or_destination_refuses_before_publication(self):
        for change in ({'transaction': 'wrong'}, {'release': 'sha256:' + 'b' * 64}, {'hostname': 'wrong'},
                       {'hostname': 'not a hostname'}, {'output_dir': str(self.directory / 'absent')}):
            self.assertEqual(self.run_task(**change)[0], 1)
        alias = self.directory / 'alias'
        alias.symlink_to(self.directory)
        self.assertEqual(self.run_task(output_dir=str(alias))[0], 1)
        alias.unlink()
        self.assertEqual(list(self.directory.iterdir()), [])

    def test_prepared_historical_or_changed_boot_cannot_admit(self):
        variants = [fixture(), accepted()]
        for key, value in (('accepted', False), ('boot_changed', False), ('expected_target_booted', False),
                           ('boot_id', '32345678-1234-1234-1234-123456789abc'), ('next_boot', 'fixture/crypt/ROOT/A')):
            data = status()
            data['observation'][key] = value
            variants.append(data)
        for data in variants:
            self.assertEqual(self.run_task(status=json.dumps(data))[0], 1, data)
        self.assertEqual(list(self.directory.iterdir()), [])

    def test_extras_and_unknown_snapshot_policy_cannot_admit(self):
        for key, value in (('owned_candidates', [{}]), ('cleanup_receipts', [{}]), ('snapshot_policy', 'delete_origins')):
            data = status()
            data[key] = value
            self.assertEqual(self.run_task(status=json.dumps(data))[0], 1)

    def test_changed_binding_cannot_complete(self):
        original = accepted('finalized')
        for path in (('id',), ('release',), ('host_identity_sha256',), ('source', 'guid'), ('shared_state', 'guid'),
                     ('policy', 'cli_sha256'), ('target_tree', 0, 'guid'), ('acceptance', 'boot_id')):
            data = copy.deepcopy(original)
            parent: Any = data
            for key in path[:-1]:
                parent = parent[key]
            value = parent[path[-1]]
            parent[path[-1]] = '9' * len(value)
            self.assertEqual(self.run_task(action='complete', report=json.dumps(data))[0], 1, path)

    def test_preview_cannot_complete_or_change_state(self):
        data = accepted('finalized')
        data.update(read_only=True, cleanup='owned', candidates=[])
        self.assertEqual(self.run_task(action='complete', report=json.dumps(data))[0], 1)
        self.assertEqual(self.run_task(action='preview', report=json.dumps(data))[0], 1)
        self.assertEqual(self.run_task(action='complete', report=json.dumps(accepted()))[0], 1)

    def test_missing_or_false_preview_flags_refuse(self):
        original = accepted()
        original.update(read_only=True, cleanup='owned', candidates=[])
        for key in ('read_only', 'cleanup', 'candidates'):
            data = copy.deepcopy(original)
            del data[key]
            self.assertEqual(self.run_task(action='preview', report=json.dumps(data))[0], 1)

    def test_duplicate_native_keys_refuse_even_when_last_value_would_pass(self):
        raw = json.dumps(status()).replace('"state": "accepted"', '"state": "prepared", "state": "accepted"')
        self.assertEqual(self.run_task(status=raw)[0], 1)
        self.assertEqual(list(self.directory.iterdir()), [])

    def test_publication_reuses_identical_bytes_and_refuses_conflict(self):
        code, receipt = self.run_task()
        self.assertEqual(code, 0)
        self.assertEqual(self.run_task()[1], receipt)
        target = Path(receipt['path'])
        target.write_text('conflicting bytes')
        self.assertEqual(self.run_task()[0], 1)
        self.assertEqual(target.read_text(), 'conflicting bytes')


if __name__ == '__main__':
    unittest.main()
