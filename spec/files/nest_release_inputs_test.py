#!/usr/bin/env python3
"""Exercise real input publication and Git identity with local disposable fixtures."""

import copy
import hashlib
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'scripts/nest-release-inputs.py'
MODULE = runpy.run_path(str(SCRIPT))
RELEASE = MODULE['release']


class ReleaseInputsTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.checkout = self.root / 'checkout'
        self.checkout.mkdir()
        self.env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM='1',
                        PYTHONDONTWRITEBYTECODE='1')
        (self.checkout / 'tracked').write_text('Fixture only\n')
        self.git('init', '-b', 'main')
        self.git('config', 'user.email', 'fixture@example.invalid')
        self.git('config', 'user.name', 'Fixture')
        self.git('add', '.')
        self.git('commit', '-m', 'Fixture only')
        self.sha = self.git('rev-parse', 'HEAD')
        self.env.update(RELEASE_INPUTS='true', CI_PROJECT_PATH='nest/config', CI_PROJECT_ID='3',
                        CI_COMMIT_SHA=self.sha, CI_PIPELINE_ID='901', CI_JOB_ID='902',
                        CI_PROJECT_DIR=str(self.checkout))
        for name in ('BUILD', 'EXECUTOR_ONLY', 'RELEASE_CANDIDATE', 'RELEASE_VALIDATE_ONLY'):
            self.env.pop(name, None)
        self.member = {'id': 'fixture-stage0', 'stage': 'stage0', 'project': 'nest/stage0',
                       'cpu': 'haswell', 'platform': None, 'variant': 'server', 'host': None,
                       'mode': 'refresh', 'bases': {'image': 'fixture.invalid/nest/base@sha256:' + 'b' * 64},
                       'compatibility': {}, 'identity_root': None}
        self.expected = {'schema': 1, 'kind': 'nest_release_expectations', 'release': 'fixture-only',
                         'sources': {'nest/config': self.sha, 'nest/overlay': 'a' * 40,
                                     'nest/gentoo/portage': 'b' * 40, 'nest/gentoo/haskell': 'c' * 40,
                                     'nest/stage0': 'd' * 40},
                         'executor': {'source': self.sha, 'image': 'fixture.invalid/nest/config/main@sha256:' + 'e' * 64},
                         'members': [self.member],
                         'consumers': [{'project': p, 'decision': 'defer', 'reason': 'Fixture only', 'members': []}
                                       for p in sorted(RELEASE['TOOL_CONSUMERS'])]
                         + [{'project': 'nest/stage0', 'decision': 'rebuild', 'reason': 'Fixture only',
                             'members': [self.member['id']]}]}
        self.input = self.root / 'input.json'
        self.input.write_text(json.dumps(self.expected, indent=2))

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.checkout), *args], env=self.env,
                                       stderr=subprocess.DEVNULL, text=True).strip()

    def cli(self, **env):
        return subprocess.run([sys.executable, str(SCRIPT), '--expectations', str(self.input)],
                              env=dict(self.env, **env), capture_output=True, text=True)

    def test_canonical_artifacts_reopened_after_producer_exit_and_input_removal(self):
        result = self.cli()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.input.unlink()
        payload = (self.checkout / 'release-inputs/expectations.json').read_bytes()
        self.assertEqual(payload, RELEASE['canonical'](self.expected))
        receipt = json.loads((self.checkout / 'release-inputs/receipt.json').read_bytes())
        self.assertEqual(receipt['artifact_sha256'], hashlib.sha256(payload).hexdigest())
        self.assertEqual(receipt['expectations_digest'], RELEASE['digest'](self.expected))
        self.assertEqual(receipt['producer'], {'project': 'nest/config', 'sha': self.sha, 'pipeline': 901, 'job': 902})
        self.assertFalse(receipt['promotion_authorized'])
        self.assertEqual(receipt['resource_verification'], 'not_performed')
        self.assertTrue(json.loads(result.stdout)['readback_verified'])
        self.assertNotIn('Fixture only', result.stdout)

    def test_existing_output_and_symlink_refuse_without_replacement(self):
        directory = self.checkout / 'release-inputs'
        directory.mkdir()
        prior = directory / 'expectations.json'
        prior.write_text('previous')
        self.assertNotEqual(self.cli().returncode, 0)
        self.assertEqual(prior.read_text(), 'previous')
        prior.unlink()
        directory.rmdir()
        directory.symlink_to(self.root, target_is_directory=True)
        self.assertNotEqual(self.cli().returncode, 0)
        self.assertFalse((self.root / 'expectations.json').exists())

    def test_wrong_or_missing_CI_identity_and_conflicting_modes_refuse(self):
        cases = [{'RELEASE_INPUTS': value} for value in ('', 'false', 'TRUE')]
        cases += [{name: 'wrong'} for name in ('CI_PROJECT_PATH', 'CI_PROJECT_ID', 'CI_COMMIT_SHA', 'CI_PIPELINE_ID', 'CI_JOB_ID')]
        cases += [{name: 'true'} for name in ('BUILD', 'EXECUTOR_ONLY', 'RELEASE_CANDIDATE', 'RELEASE_VALIDATE_ONLY')]
        cases += [{'CI_PROJECT_DIR': '.'}, {'CI_COMMIT_SHA': 'f' * 40}]
        for case in cases:
            with self.subTest(case=case):
                self.assertNotEqual(self.cli(**case).returncode, 0)
                self.assertFalse((self.checkout / 'release-inputs').exists())

    def test_modified_tracked_checkout_refuses(self):
        (self.checkout / 'tracked').write_text('changed')
        self.assertNotEqual(self.cli().returncode, 0)
        self.assertFalse((self.checkout / 'release-inputs').exists())

    def test_other_executor_source_internally_consistent_but_not_this_CI_refuses(self):
        self.expected['sources']['nest/config'] = 'f' * 40
        self.expected['executor']['source'] = 'f' * 40
        self.input.write_text(json.dumps(self.expected))
        self.assertNotEqual(self.cli().returncode, 0)
        self.assertFalse((self.checkout / 'release-inputs').exists())

    def test_missing_duplicate_or_unclassified_selection_refuses(self):
        for mutate in (lambda e: e['members'].clear(), lambda e: e['members'].append(copy.deepcopy(self.member)),
                       lambda e: e['consumers'].pop(0), lambda e: e['sources'].pop('nest/gentoo/haskell'),
                       lambda e: e['members'][0]['bases'].update(image='fixture.invalid/nest/base:latest')):
            expected = copy.deepcopy(self.expected)
            mutate(expected)
            self.input.write_text(json.dumps(expected))
            self.assertNotEqual(self.cli().returncode, 0)
            self.assertFalse((self.checkout / 'release-inputs').exists())

    def test_malformed_duplicate_nonfinite_and_oversized_inputs_refuse_safely(self):
        for raw in ('private-secret-error', '{"schema":1,"schema":1}', '{"schema":NaN}', 'x' * (RELEASE['LIMIT'] + 1)):
            self.input.write_text(raw)
            result = self.cli()
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn('private-secret-error', result.stderr)
            self.assertNotIn('Traceback', result.stderr)
            self.assertFalse((self.checkout / 'release-inputs').exists())

    def test_input_symlink_refuses(self):
        link = self.root / 'link.json'
        link.symlink_to(self.input)
        self.input = link
        self.assertNotEqual(self.cli().returncode, 0)

    def test_failed_fsync_and_changed_readback_refuse(self):
        with patch('os.fsync', side_effect=OSError('fixture')):
            with self.assertRaises(OSError):
                MODULE['publish'](self.input, self.env)
        # Failure does not permit replacement/replay in the same job directory.
        self.assertNotEqual(self.cli().returncode, 0)

    def test_changed_artifact_readback_refuses(self):
        original = Path.read_bytes

        def read(path):
            data = original(path)
            return b'changed' if path.name == 'receipt.json' else data

        with patch.object(Path, 'read_bytes', read):
            with self.assertRaises(RELEASE['Invalid']):
                MODULE['publish'](self.input, self.env)
        self.assertNotEqual(self.cli().returncode, 0)


if __name__ == '__main__':
    unittest.main()
