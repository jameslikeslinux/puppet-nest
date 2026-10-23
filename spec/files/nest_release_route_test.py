#!/usr/bin/env python3
"""Offline bridge compilation, strict route admission and real publisher fixtures."""

import copy
import hashlib
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
ROUTE = runpy.run_path(str(ROOT / 'scripts/nest-release-route.py'))
INPUTS = runpy.run_path(str(ROOT / 'spec/files/nest_release_inputs_test.py'))
BIND = runpy.run_path(str(ROOT / 'spec/files/nest_release_bind_test.py'))
R = ROUTE['R']


class ReleaseRouteTest(unittest.TestCase):
    def setUp(self):
        self.fixture = INPUTS['ReleaseInputsTest']()
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.f = self.fixture
        self.f.env.update(CI_PIPELINE_SOURCE='api', RELEASE_ROUTE='true',
                          RELEASE_ROUTE_MEMBER=self.f.member['id'],
                          RELEASE_ROUTE_EXECUTOR_PIPELINE='900', RELEASE_ROUTE_EXECUTOR_JOB='901')
        self.f.expected['executor']['image'] = 'registry.gitlab.joyfullee.me/nest/config/main@sha256:' + 'e' * 64
        self.save()
        self.api = BIND['FakeGitLab']()
        self.api.expected = copy.deepcopy(self.f.expected)
        self.api.jobs[('nest/config', 901)] = self.api.make_job('nest/config', 900, 901, 'Build haswell')
        self.executor = BIND['receipt'](self.f.expected)
        self.api.artifacts[('nest/config', 901, 'executor-receipts/haswell.json')] = self.executor

    def save(self):
        self.f.input.write_bytes(R['canonical'](self.f.expected))

    def publish(self, **changes):
        return INPUTS['MODULE']['publish'](self.f.input, dict(self.f.env, **changes), api=self.api)

    def test_routes_exact_reopened_bytes_and_pins_without_forwarded_secrets(self):
        self.f.env['CI_JOB_TOKEN'] = 'fixture-private-token'
        receipt = self.publish()
        self.f.input.unlink()
        raw = (self.f.checkout / 'release-inputs/candidate.yml').read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(), receipt['candidate_route']['artifact_sha256'])
        graph = json.loads(raw)
        job = graph['Build frozen member']
        self.assertEqual(job['trigger'], dict(project='nest/stage0', branch='main', strategy='mirror',
                                             forward=dict(yaml_variables=True, pipeline_variables=False)))
        self.assertFalse(job['allow_failure'])
        self.assertEqual(job['inherit'], dict(variables=False))
        self.assertEqual(graph['workflow']['rules'][0], {'if': '$CI_PIPELINE_SOURCE == "parent_pipeline"'})
        self.assertNotIn('script', job)
        variables = job['variables']
        self.assertEqual(variables['RELEASE_INPUT_JOB_ID'], '902')
        self.assertEqual(variables['RELEASE_INPUT_SHA256'], receipt['artifact_sha256'])
        self.assertEqual(variables['RELEASE_EXECUTOR_JOB_ID'], '901')
        self.assertEqual(variables['RELEASE_EXECUTOR_IMAGE'], self.executor['image'])
        self.assertEqual(variables['RELEASE_MEMBER'], self.f.member['id'])
        self.assertNotIn('RELEASE_VARIANT', variables)  # Stage 0 explicitly forbids it.
        self.assertFalse(any(key in variables for key in ROUTE['ROUTE_KEYS']))
        self.assertNotIn(b'fixture-private-token', raw)
        self.assertEqual(receipt['candidate_route']['execution'], 'not_started')
        self.assertFalse(receipt['promotion_authorized'])
        self.assertEqual(self.f.expected['members'][0]['bases'], self.f.member['bases'])

    def test_absent_route_is_compatible_but_any_partial_or_malformed_selection_refuses(self):
        plain = {k: v for k, v in self.f.env.items() if k not in ROUTE['ROUTE_KEYS']}
        self.assertFalse(ROUTE['selected'](plain))
        for name in ROUTE['ROUTE_KEYS']:
            env = dict(plain, **{name: 'invalid'})
            with self.subTest(key=name), self.assertRaises(ValueError):
                ROUTE['selected'](env)
        for key, value in [('RELEASE_ROUTE', 'false'), ('RELEASE_ROUTE_MEMBER', 'x\nscript:'),
                           ('RELEASE_ROUTE_EXECUTOR_JOB', '01'), ('RELEASE_ROUTE_EXECUTOR_PIPELINE', '1\n')]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.publish(**{key: value})
        self.assertFalse((self.f.checkout / 'release-inputs').exists())

    def test_all_sources_and_every_conflict_are_checked_before_external_reads(self):
        for source in ('push', 'merge_request_event', 'schedule', 'parent_pipeline', ''):
            with self.subTest(source=source), self.assertRaises(ValueError):
                self.publish(CI_PIPELINE_SOURCE=source)
        for key in ROUTE['CONFLICTS'] + ('CI_COMMIT_TAG',):
            for value in ('true', 'false', ' ', '\n'):
                with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                    self.publish(**{key: value})
        self.assertEqual(self.api.reads, [])
        self.assertFalse((self.f.checkout / 'release-inputs').exists())
        for source in ('api', 'web', 'pipeline', 'trigger'):
            self.assertTrue(ROUTE['selected'](dict(self.f.env, CI_PIPELINE_SOURCE=source)))

    def test_parent_source_requires_exact_scoped_freezer_job(self):
        member = self.f.env['RELEASE_ROUTE_MEMBER']
        for name in ('Freeze release inputs', 'Freeze release inputs sibling',
                     'Freeze release inputs  ' + member, 'Freeze release inputs ' + member + '\n', ''):
            with self.subTest(name=name), self.assertRaises(ValueError):
                self.publish(CI_PIPELINE_SOURCE='parent_pipeline', CI_JOB_NAME=name)
        self.assertEqual(self.api.reads, [])
        receipt = self.publish(CI_PIPELINE_SOURCE='parent_pipeline', CI_JOB_NAME='Freeze release inputs ' + member)
        self.assertEqual(receipt['candidate_route']['member'], member)

    def test_unknown_reuse_and_unimplemented_tool_refuse(self):
        with self.assertRaises(ValueError): self.publish(RELEASE_ROUTE_MEMBER='absent')
        self.f.expected['consumers'][-1]['decision'] = 'reuse'
        self.save()
        with self.assertRaises(ValueError): self.publish()
        self.assertFalse((self.f.checkout / 'release-inputs').exists())

    def test_exact_executor_faults_refuse_before_publication(self):
        for change in ('failed', 'erased', 'source', 'wrong_name', 'cpu', 'pipeline', 'job', 'image', 'schema', 'module'):
            with self.subTest(change=change):
                row = self.api.jobs[('nest/config', 901)]
                before_job, before_executor = copy.deepcopy(row), copy.deepcopy(self.executor)
                if change == 'failed': row['status'] = 'failed'
                if change == 'erased': row['erased_at'] = 'fixture'
                if change == 'source': row['commit']['id'] = 'f' * 40
                if change == 'wrong_name': row['name'] = 'Build cortex-a53'
                if change == 'cpu': self.executor['cpu'] = 'cortex-a53'
                if change == 'pipeline': self.executor['pipeline'] = 899
                if change == 'job': self.executor['job'] = 899
                if change == 'image': self.executor['image'] = BIND['MANIFEST']['image'](11)
                if change == 'schema': self.executor['schema'] = 1
                if change == 'module': self.executor['inputs']['modules'] = []
                with self.assertRaises(ValueError): self.publish()
                self.assertFalse((self.f.checkout / 'release-inputs').exists())
                row.clear(); row.update(before_job)
                self.executor.clear(); self.executor.update(before_executor)
        with self.assertRaises(ValueError): self.publish(RELEASE_ROUTE_EXECUTOR_JOB='902')

    def test_executor_change_between_reads_refuses(self):
        original = self.api.get
        reads = 0

        def get(path):
            nonlocal reads
            raw = original(path)
            if path.endswith('/executor-receipts/haswell.json'):
                reads += 1
                if reads == 1:
                    self.api.jobs[('nest/config', 901)]['erased_at'] = 'fixture'
            return raw

        with patch.object(self.api, 'get', get), self.assertRaises(ValueError): self.publish()
        self.assertFalse((self.f.checkout / 'release-inputs').exists())

    def test_all_stage_and_tool_routes_use_exact_member_fields_and_architecture(self):
        for project, stage in [(f'nest/stage{i}', f'stage{i}') for i in range(4)] + [
                (f'nest/tools/{tool}', 'tool') for tool in ('bolt', 'pdk', 'agent', 'firefox', 'camofox', 'llama.cpp')]:
            for cpu, executor_cpu in [('haswell', 'haswell'), ('cortex-a53', 'cortex-a53'), ('sifive-u74', 'sifive-u74')]:
                with self.subTest(project=project, cpu=cpu):
                    expected, _ = BIND['MANIFEST']['fixture']()
                    member = next(copy.deepcopy(m) for m in expected['members'] if m['stage'] == stage)
                    member.update(id='selected-member', project=project, cpu=cpu)
                    expected['sources'][project] = 'd' * 40
                    expected['executor']['image'] = self.f.expected['executor']['image']
                    expected['members'] = [member]
                    for consumer in expected['consumers']:
                        consumer.update(decision='rebuild' if consumer['project'] == project else 'defer',
                                        members=[member['id']] if consumer['project'] == project else [])
                    if not any(c['project'] == project for c in expected['consumers']):
                        expected['consumers'].append(dict(project=project, decision='rebuild', reason='Fixture only', members=[member['id']]))
                    api = BIND['FakeGitLab']()
                    api.expected = expected
                    api.jobs[('nest/config', 901)] = api.make_job('nest/config', 900, 901, 'Build ' + executor_cpu)
                    api.artifacts[('nest/config', 901, 'executor-receipts/' + executor_cpu + '.json')] = BIND['receipt'](expected, executor_cpu)
                    env = dict(self.f.env, RELEASE_ROUTE_MEMBER=member['id'])
                    if stage == 'stage3': env['RELEASE_ROUTE_PLACEMENT'] = '/fixture/local/placement.json'
                    receipt = dict(producer=dict(job=902), artifact_sha256='a' * 64)
                    graph = ROUTE['compile_bridge'](expected, receipt, env, api)
                    variables = graph['Build frozen member']['variables']
                    self.assertEqual(graph['Build frozen member']['trigger']['project'], project)
                    self.assertEqual(variables['RELEASE_CPU'], cpu)
                    if stage != 'stage0': self.assertEqual(variables['RELEASE_VARIANT'], member['variant'])
                    if stage in ('stage2', 'stage3'): self.assertEqual(variables['RELEASE_PLATFORM'], member['platform'])
                    if stage == 'stage3':
                        self.assertEqual(variables['RELEASE_HOST'], member['host'])
                        self.assertEqual(variables['HOSTNAME'], '')
                        self.assertEqual(variables['RELEASE_STAGE3_PLACEMENT_FILE'], '/fixture/local/placement.json')
                        for placement in ('relative', '/path/../file', '/path/$TOKEN'):
                            with self.assertRaises(ValueError):
                                ROUTE['compile_bridge'](expected, receipt, dict(env, RELEASE_ROUTE_PLACEMENT=placement), api)
                    else:
                        with self.assertRaises(ValueError):
                            ROUTE['compile_bridge'](expected, receipt, dict(env, RELEASE_ROUTE_PLACEMENT='/fixture'), api)

    def test_native_discovery_routes_final_bound_bytes_not_seed_digest(self):
        api, _ = self.f.native()
        expected = api.request['expectations']
        expected['executor']['image'] = self.f.expected['executor']['image']
        api.executor['image'] = expected['executor']['image']
        api.expected['executor']['image'] = expected['executor']['image']
        api.result['output']['executor']['image'] = expected['executor']['image']
        api.result['expectations_digest'] = R['digest'](api.expected)
        self.f.input.write_bytes(R['canonical'](api.request))
        self.f.env['RELEASE_ROUTE_MEMBER'] = expected['members'][0]['id']
        receipt = INPUTS['MODULE']['publish'](self.f.input, self.f.env, discovery=True, api=api)
        directory = self.f.checkout / 'release-inputs'
        frozen = (directory / 'expectations.json').read_bytes()
        self.assertEqual(json.loads(frozen)['members'][0]['bases'], api.result['output']['artifacts'])
        variables = json.loads((directory / 'candidate.yml').read_bytes())['Build frozen member']['variables']
        self.assertEqual(variables['RELEASE_INPUT_SHA256'], hashlib.sha256(frozen).hexdigest())
        self.assertIn('base_discovery', receipt)
        self.assertIn('candidate_route', receipt)

    def test_failed_candidate_readback_cannot_report_success_or_overwrite(self):
        original = Path.read_bytes

        def read(path):
            return b'changed' if path.name == 'candidate.yml' else original(path)

        with patch.object(Path, 'read_bytes', read), self.assertRaises(ValueError): self.publish()
        with self.assertRaises(FileExistsError): self.publish()

    def test_real_cli_uses_only_allowlisted_GETs_and_reopens_generated_graph(self):
        # Capture the exact permitted reads, then exercise the actual publisher in
        # a separate process with fake glab. No real build or trigger exists here.
        replies = {}
        original = self.api.get

        def get(path):
            raw = original(path)
            replies[path] = raw
            return raw

        receipt = dict(producer=dict(job=902), artifact_sha256='a' * 64)
        with patch.object(self.api, 'get', get):
            ROUTE['compile_bridge'](self.f.expected, receipt, self.f.env, self.api)
        binary = self.f.root / 'bin'
        binary.mkdir()
        BIND['fake_glab'](binary / 'glab', replies)
        result = self.f.cli(PATH=str(binary) + os.pathsep + self.f.env['PATH'])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.f.input.unlink()
        self.assertTrue(json.loads(result.stdout)['readback_verified'])
        retained = self.f.checkout / 'release-inputs'
        self.assertEqual(json.loads((retained / 'candidate.yml').read_bytes())['Build frozen member']['variables']['RELEASE_INPUT_JOB_ID'], '902')
        self.assertNotIn('Traceback', result.stderr)


if __name__ == '__main__':
    unittest.main()
