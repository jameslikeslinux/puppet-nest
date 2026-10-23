#!/usr/bin/env python3
"""Nonpublishing nested topology generation and fail-closed admission."""
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
SCRIPT = ROOT / 'scripts/nest-release-dag-fixture.py'
P = runpy.run_path(str(SCRIPT))


class NestedDagFixtureTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        for args in (['init', '-b', 'main'], ['config', 'user.name', 'Fixture'],
                     ['config', 'user.email', 'fixture@example.invalid'], ['config', 'commit.gpgsign', 'false']):
            subprocess.run(['git', '-C', str(self.root)] + args, check=True, capture_output=True)
        (self.root / 'source').write_text('fixture\n')
        subprocess.run(['git', '-C', str(self.root), 'add', 'source'], check=True)
        subprocess.run(['git', '-C', str(self.root), 'commit', '-m', 'fixture'], check=True, capture_output=True)
        source = subprocess.check_output(['git', '-C', str(self.root), 'rev-parse', 'HEAD'], text=True).strip()
        self.env = dict(PATH=os.defpath, CI_PROJECT_DIR=str(self.root), CI_PROJECT_PATH='nest/config',
                        CI_COMMIT_BRANCH='main', CI_COMMIT_SHA=source, CI_PIPELINE_ID='41', CI_JOB_ID='42',
                        CI_JOB_NAME='Compile nested DAG fixture', CI_PIPELINE_SOURCE='api',
                        NEST_DAG_FIXTURE='nested-stage1-pass', PYTHONDONTWRITEBYTECODE='1')

    def test_exact_sources_and_modes(self):
        for source in ('api', 'web', 'pipeline', 'parent_pipeline', 'push', 'schedule', 'merge_request_event', 'trigger', ''):
            for mode in ('nested-stage1-pass', 'nested-stage1-fail', 'node-stage1-pass', 'node-stage1-fail',
                         'nested-stage1-true', 'nested-stage2-pass', 'nested-stage1-pass ', 'false', '', ' '):
                expected = ((source in ('api', 'web') and mode in ('nested-stage1-pass', 'nested-stage1-fail')) or
                            (source == 'pipeline' and mode in ('node-stage1-pass', 'node-stage1-fail')))
                self.assertEqual(P['admitted'](dict(self.env, CI_PIPELINE_SOURCE=source, NEST_DAG_FIXTURE=mode)), expected)

    def test_every_conflict_including_whitespace_refuses_before_publication(self):
        for key in P['CONFLICTS'] + ('CI_COMMIT_TAG',):
            for value in ('true', 'false', ' ', '\n'):
                with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                    P['compile_nested'](dict(self.env, **{key: value}))
        self.assertFalse((self.root / 'nested-dag-fixture').exists())

    def test_root_child_is_required_config_bridge_with_only_fixed_fixture_mode(self):
        receipt = P['compile_nested'](self.env)
        directory = self.root / 'nested-dag-fixture'
        raw = (directory / 'child.yml').read_bytes()
        child = json.loads(raw)
        self.assertEqual(set(child), {'workflow', 'stages', 'Fixture config node'})
        bridge = child['Fixture config node']
        self.assertFalse(bridge['allow_failure'])
        self.assertEqual(bridge['inherit'], {'variables': False})
        self.assertEqual(bridge['variables'], {'NEST_DAG_FIXTURE': 'node-stage1-pass'})
        self.assertEqual(bridge['trigger'], dict(project='nest/config', branch='main', strategy='mirror',
                                               forward=dict(yaml_variables=True, pipeline_variables=False)))
        self.assertEqual(child['workflow']['rules'], [{'if': '$CI_PIPELINE_SOURCE == "parent_pipeline"'}, {'when': 'never'}])
        self.assertEqual(receipt, json.loads((directory / 'receipt.json').read_bytes()))
        self.assertEqual(receipt['child_sha256'], hashlib.sha256(raw).hexdigest())
        self.assertEqual((receipt['source'], receipt['pipeline'], receipt['job']), (self.env['CI_COMMIT_SHA'], 41, 42))
        self.assertEqual(receipt['layer'], 'root')
        self.assertTrue(all(receipt[key] is False for key in ('candidate_builds', 'publication', 'host_actions')))

    def test_node_child_selects_only_existing_nonpublishing_leaf(self):
        for outcome in ('pass', 'fail'):
            with self.subTest(outcome=outcome):
                env = dict(self.env, CI_PIPELINE_SOURCE='pipeline', NEST_DAG_FIXTURE='node-stage1-' + outcome)
                receipt = P['compile_nested'](env)
                directory = self.root / 'nested-dag-fixture'
                child = json.loads((directory / 'child.yml').read_bytes())
                bridge = child['Fixture Stage 1 leaf']
                self.assertEqual(set(child), {'workflow', 'stages', 'Fixture Stage 1 leaf'})
                self.assertFalse(bridge['allow_failure'])
                self.assertEqual(bridge['inherit'], {'variables': False})
                self.assertEqual(bridge['trigger'], dict(project='nest/stage1', branch='main', strategy='mirror',
                                                       forward=dict(yaml_variables=True, pipeline_variables=False)))
                self.assertEqual(bridge['variables'], dict(RELEASE_DAG='true', RELEASE_VALIDATE_ONLY='true',
                                                          RELEASE_DAG_FIXTURE=outcome))
                self.assertEqual(receipt['layer'], 'node')
                for path in directory.iterdir():
                    path.unlink()
                directory.rmdir()

    def test_wrong_source_project_job_or_resource_refuses(self):
        for key, value in (('CI_PROJECT_PATH', 'other/config'), ('CI_COMMIT_BRANCH', 'feature'),
                           ('CI_JOB_NAME', 'Build haswell'), ('CI_COMMIT_SHA', 'a' * 40),
                           ('CI_PIPELINE_ID', '0'), ('CI_JOB_ID', '-1'), ('CI_JOB_ID', '１２'), ('CI_JOB_ID', ' 42')):
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                P['compile_nested'](dict(self.env, **{key: value}))
        (self.root / 'source').write_text('changed\n')
        with self.assertRaises(ValueError):
            P['compile_nested'](self.env)
        self.assertFalse((self.root / 'nested-dag-fixture').exists())

    def test_no_clobber_or_replay(self):
        P['compile_nested'](self.env)
        directory = self.root / 'nested-dag-fixture'
        before = {path.name: path.read_bytes() for path in directory.iterdir()}
        with self.assertRaises(FileExistsError):
            P['compile_nested'](dict(self.env, NEST_DAG_FIXTURE='nested-stage1-fail'))
        self.assertEqual(before, {path.name: path.read_bytes() for path in directory.iterdir()})

    def test_readback_failure_is_not_success(self):
        original = Path.read_bytes
        def changed(path):
            raw = original(path)
            return b'changed' if path.name == 'child.yml' else raw
        with patch.object(Path, 'read_bytes', changed), self.assertRaisesRegex(ValueError, 'readback'):
            P['compile_nested'](self.env)

    def test_real_cli_does_not_print_private_values(self):
        env = dict(self.env, CI_JOB_TOKEN='private-fixture-token')
        result = subprocess.run([sys.executable, str(SCRIPT), '--compile-nested'], env=env,
                                capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        failed = subprocess.run([sys.executable, str(SCRIPT), '--compile-nested'], env=env,
                                capture_output=True, text=True, check=False)
        self.assertEqual(failed.returncode, 1)
        self.assertNotIn('private-fixture-token', result.stdout + result.stderr + failed.stdout + failed.stderr)
        for path in (self.root / 'nested-dag-fixture').iterdir():
            self.assertNotIn(b'private-fixture-token', path.read_bytes())


if __name__ == '__main__':
    unittest.main()
