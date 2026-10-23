#!/usr/bin/env python3
"""Offline native DAG compiler and actual predecessor-freezing fault fixtures."""

import copy
import hashlib
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
import unittest
from typing import Any
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
G = runpy.run_path(str(ROOT / 'scripts/nest-release-graph.py'))
F = runpy.run_path(str(ROOT / 'spec/files/nest_release_bind_test.py'))
P = runpy.run_path(str(ROOT / 'spec/files/nest_release_inputs_test.py'))
R = G['R']


def request(expected) -> Any:
    nodes = []
    for member in expected['members']:
        edges = [dict(base=role, producer='stage0', artifact=role) for role in ('normal', 'debug')] if member['id'] == 'stage1' else []
        nodes.append(dict(member=member['id'], job_name='Candidate haswell' if member['stage'] == 'stage0' else 'Candidate haswell-server',
                          placement=None, bindings=edges))
    return dict(schema=1, kind='nest_release_graph', expectations=copy.deepcopy(expected),
                executor_job=dict(pipeline=900, job=901), nodes=nodes)


class NativeGraph(F['FakeGitLab']):
    after_get: Any

    def __init__(self, expected):
        super().__init__()
        self.expected = expected
        self.executor = F['receipt'](expected)
        self.graph = request(expected)
        self.jobs[('nest/config', 901)] = self.make_job('nest/config', 900, 901, 'Build haswell')
        self.jobs[('nest/config', 601)] = self.make_job('nest/config', 600, 601, 'Compile release graph')
        self.jobs[('nest/config', 801)] = self.make_job('nest/config', 650, 801, 'Freeze release inputs stage0')
        self.jobs[('nest/config', 9011)] = self.make_job('nest/config', 650, 9011, 'Freeze release inputs stage1')
        self.jobs[('nest/stage0', 101)] = self.make_job('nest/stage0', 1, 101, 'Candidate haswell')
        for job in self.jobs.values(): job['allow_failure'] = False
        self.jobs[('nest/config', 9011)]['status'] = 'running'
        self.result['release'] = expected['release']
        self.result['executor_receipt'] = self.executor
        projected = G['I']['project_member'](expected, 'stage0')
        self.result['expectations_digest'] = R['digest'](projected)
        self.result['output']['member'] = copy.deepcopy(expected['members'][0])
        self.result['output']['executor'] = expected['executor']
        self.result['output']['producer']['sha'] = expected['sources']['nest/stage0']
        self.artifacts = {('nest/config', 901, 'executor-receipts/haswell.json'): self.executor,
                          ('nest/config', 601, 'release-graph/request.json'): self.graph,
                          ('nest/config', 801, 'release-inputs/expectations.json'): projected,
                          ('nest/stage0', 101, 'release-results/stage0.json'): self.result}
        self.pipelines = {i: self.pipeline(i, source, status) for i, source, status in (
            (600, 'api', 'running'), (650, 'parent_pipeline', 'running'),
            (850, 'parent_pipeline', 'success'))}
        self.pipelines[1] = self.pipeline(1, 'pipeline', 'success', project='nest/stage0')
        self.bridges = {
            600: [self.bridge(610, 'Run release graph', 600, 650, 'running')],
            650: [self.bridge(660, 'Release node stage0', 650, 850)],
            850: [self.bridge(860, 'Build frozen member', 850, 1)], 1: []}
        self.pipeline_jobs = {650: [self.jobs[('nest/config', 801)], self.jobs[('nest/config', 9011)]],
                              1: [self.jobs[('nest/stage0', 101)]]}
        self.after_get = None

    def pipeline(self, number, source, status, project='nest/config'):
        return dict(id=number, project_id=3 if project == 'nest/config' else 10,
                    sha=self.expected['sources'][project], ref='main', source=source, status=status)

    def bridge(self, number, name, parent, child, status='success'):
        return dict(id=number, name=name, status=status, allow_failure=False,
                    pipeline=copy.deepcopy(self.pipelines[parent]),
                    downstream_pipeline=copy.deepcopy(self.pipelines.get(child)))

    def get(self, path):
        parts = path.split('/')
        if len(parts) >= 4 and parts[2] == 'pipelines':
            number = int(parts[3])
            if len(parts) == 4: row = self.pipelines[number]
            elif parts[4].startswith('bridges'): row = self.bridges[number]
            else: row = self.pipeline_jobs[number]
            self.reads.append(path)
            raw = R['canonical'](row)
        else:
            raw = super().get(path)
        if self.after_get: self.after_get(path)
        return raw


class GraphTest(unittest.TestCase):
    leaf: Any

    def setUp(self):
        self.f = P['ReleaseInputsTest']()
        self.f.setUp()
        self.addCleanup(self.f.doCleanups)
        base = F['FakeGitLab']().expected
        base['sources']['nest/config'] = self.f.sha
        base['executor'].update(source=self.f.sha, image='registry.gitlab.joyfullee.me/nest/config/main@sha256:' + 'e' * 64)
        self.api = NativeGraph(base)
        self.request = self.api.graph
        self.env = dict(self.f.env, CI_PIPELINE_SOURCE='api', CI_PIPELINE_ID='600', CI_JOB_ID='601',
                        CI_COMMIT_BRANCH='main',
                        CI_JOB_NAME='Compile release graph', RELEASE_GRAPH='true', RELEASE_GRAPH_FILE='/fixture/graph.json')
        self.env.pop('RELEASE_INPUTS')
        self.node_env = dict(self.f.env, CI_PIPELINE_SOURCE='parent_pipeline', CI_PIPELINE_ID='650', CI_JOB_ID='9011',
                             CI_JOB_NAME='Freeze release inputs stage1', RELEASE_GRAPH_NODE='true', RELEASE_GRAPH_MEMBER='stage1',
                             RELEASE_GRAPH_INPUT_PIPELINE='600', RELEASE_GRAPH_INPUT_JOB='601',
                             RELEASE_GRAPH_INPUT_SHA256=hashlib.sha256(R['canonical'](self.request)).hexdigest(),
                             RELEASE_GRAPH_ROOT_PIPELINE='650')

    def test_public_compile_refuses_unsupported_topology_without_publication(self):
        completed = subprocess.run([sys.executable, str(ROOT / 'scripts/nest-release-graph.py'), '--compile'],
                                   cwd=self.f.checkout, env=self.env, capture_output=True, text=True, check=False)
        self.assertEqual(completed.returncode, 1)
        self.assertIn('flattened graph acceptance pending', completed.stderr)
        self.assertFalse((self.f.checkout / 'release-graph').exists())

    def test_compiles_exact_native_dependencies_and_reopens_no_clobber_artifacts(self):
        before = copy.deepcopy(self.request)
        self.env['CI_JOB_TOKEN'] = 'fixture-private-value'
        receipt = G['compile_graph'](self.request, self.env)
        directory = self.f.checkout / 'release-graph'
        graph = json.loads((directory / 'graph.yml').read_bytes())
        self.assertEqual(graph['Freeze release inputs stage0']['needs'], [])
        self.assertEqual(graph['Freeze release inputs stage1']['needs'], ['Release node stage0'])
        for name in ('stage0', 'stage1'):
            job = graph['Release node ' + name]
            freezer = 'Freeze release inputs ' + name
            self.assertEqual(job['needs'], [freezer])
            self.assertFalse(job['allow_failure'])
            self.assertEqual(job['trigger'], dict(include=[dict(artifact='release-inputs/candidate.yml', job=freezer)], strategy='mirror',
                                                 forward=dict(yaml_variables=True, pipeline_variables=False)))
            self.assertEqual(job['inherit'], dict(variables=False))
            self.assertNotIn('variables', job)
            frozen = graph[freezer]
            self.assertEqual(frozen['variables']['RELEASE_GRAPH_ROOT_PIPELINE'], '$CI_PIPELINE_ID')
            self.assertNotIn('RELEASE_GRAPH', frozen['variables'])
            self.assertEqual(frozen['script'], ['python3 scripts/nest-release-graph.py --freeze-node'])
            self.assertEqual(frozen['artifacts'], dict(when='on_success', paths=['release-inputs/']))
        self.assertNotIn(b'fixture-private-value', (directory / 'graph.yml').read_bytes())
        self.assertEqual(hashlib.sha256((directory / 'request.json').read_bytes()).hexdigest(), receipt['request_sha256'])
        self.assertEqual(self.request, before)
        self.assertFalse(receipt['promotion_authorized'])
        with self.assertRaises(FileExistsError): G['compile_graph'](self.request, self.env)

    def test_descendant_freezes_actual_successful_predecessor_pair_before_routing(self):
        before = copy.deepcopy(self.request)
        F['digest_results'](self.api.artifacts)
        receipt = G['freeze_node'](self.node_env, self.api)
        directory = self.f.checkout / 'release-inputs'
        frozen = R['load'](directory / 'expectations.json')
        self.assertEqual([m['id'] for m in frozen['members']], ['stage1'])
        self.assertEqual(frozen['members'][0]['bases'], self.api.result['output']['artifacts'])
        self.assertEqual(self.request, before)
        route = R['load'](directory / 'candidate.yml')['Build frozen member']
        self.assertEqual(route['trigger']['project'], 'nest/stage1')
        self.assertEqual(route['variables']['RELEASE_INPUT_JOB_ID'], '9011')
        self.assertEqual(route['variables']['RELEASE_INPUT_SHA256'], receipt['artifact_sha256'])
        self.assertEqual(route['variables']['RELEASE_EXECUTOR_JOB_ID'], '901')
        self.assertNotIn('RELEASE_GRAPH_NODE', route['variables'])
        self.assertIn('base_discovery', R['load'](directory / 'provenance.json'))
        self.assertNotIn('base_discovery', receipt)
        with self.assertRaises(FileExistsError): G['freeze_node'](self.node_env, self.api)

    def test_root_node_uses_reviewed_pinned_bases_without_predecessor_acquisition(self):
        env = dict(self.node_env, RELEASE_GRAPH_MEMBER='stage0', CI_JOB_ID='801', CI_JOB_NAME='Freeze release inputs stage0')
        self.api.jobs[('nest/config', 801)]['status'] = 'running'
        G['freeze_node'](env, self.api)
        frozen = R['load'](self.f.checkout / 'release-inputs/expectations.json')
        self.assertEqual(frozen, G['I']['project_member'](self.request['expectations'], 'stage0'))
        self.assertEqual(R['load'](self.f.checkout / 'release-inputs/closure.json'), self.request['expectations'])
        self.assertFalse(any('/projects/nest%2Fstage0' in p for p in self.api.reads))

    def test_flattened_freezer_exact_identity_and_no_legacy_or_sibling_substitution(self):
        for change in ('legacy', 'sibling', 'duplicate', 'erased', 'tolerated', 'failed', 'pipeline', 'commit', 'job', 'name'):
            api = NativeGraph(copy.deepcopy(self.api.expected))
            env = dict(self.node_env)
            row = api.jobs[('nest/config', 9011)]
            if change == 'legacy': row['name'] = 'Freeze release inputs'
            if change == 'sibling': row['name'] = 'Freeze release inputs stage0'
            if change == 'duplicate': api.pipeline_jobs[650].append(copy.deepcopy(row))
            if change == 'erased': row['erased_at'] = 'fixture'
            if change == 'tolerated': row['allow_failure'] = True
            if change == 'failed': row['status'] = 'failed'
            if change == 'pipeline': row['pipeline']['id'] = 651
            if change == 'commit': row['commit']['id'] = 'f' * 40
            if change == 'job': env['CI_JOB_ID'] = '9012'
            if change == 'name': env['CI_JOB_NAME'] = 'Freeze release inputs stage1 '
            with self.subTest(change=change), self.assertRaises(ValueError): G['freeze_node'](env, api)
            self.assertFalse((self.f.checkout / 'release-inputs').exists())

    def test_running_siblings_and_volatile_job_fields_do_not_block_exact_predecessor(self):
        self.api.pipeline_jobs[650].append(dict(id=990, name='Freeze release inputs sibling', status='running'))
        def after(path):
            if '/pipelines/650/jobs?' in path:
                row = self.api.jobs[('nest/config', 9011)]
                row['duration'] = row.get('duration', 0) + 1
                row['runner'] = dict(contacted_at=str(row['duration']))
        self.api.after_get = after
        G['freeze_node'](self.node_env, self.api)
        self.assertTrue((self.f.checkout / 'release-inputs/candidate.yml').exists())

    def test_running_freezer_replacement_during_acquisition_refuses_before_publication(self):
        def after(path):
            if path.endswith('/jobs/901/artifacts/executor-receipts/haswell.json'):
                self.api.jobs[('nest/config', 9011)]['id'] = 9012
        self.api.after_get = after
        with self.assertRaises(ValueError): G['freeze_node'](self.node_env, self.api)
        self.assertFalse((self.f.checkout / 'release-inputs').exists())

    def test_flattened_predecessor_refuses_ambiguous_or_wrong_freezer_and_old_node_layer(self):
        for change in ('legacy', 'duplicate', 'failed', 'old-node', 'extra-route'):
            api = NativeGraph(copy.deepcopy(self.api.expected))
            if change == 'legacy': api.jobs[('nest/config', 801)]['name'] = 'Freeze release inputs'
            if change == 'duplicate':
                extra = copy.deepcopy(api.jobs[('nest/config', 801)])
                extra.update(id=802, name='Freeze release inputs')
                api.pipeline_jobs[650].append(extra)
            if change == 'failed': api.jobs[('nest/config', 801)]['status'] = 'failed'
            if change == 'old-node': api.pipelines[850]['source'] = 'pipeline'
            if change == 'extra-route': api.bridges[850].append(dict(id=870, name='Unexpected'))
            with self.subTest(change=change), self.assertRaises(ValueError):
                G['native_node'](api, self.request, 650, 'stage0')

    def test_partial_modes_conflicts_and_nonoperator_graph_sources_refuse(self):
        plain = {k: v for k, v in self.env.items() if k not in G['KEYS']}
        self.assertIsNone(G['selected'](plain))
        for key in G['KEYS']:
            with self.subTest(key=key), self.assertRaises(ValueError): G['selected'](dict(plain, **{key: 'false'}))
        for source in ('pipeline', 'parent_pipeline', 'push', 'merge_request_event', 'schedule', ''):
            with self.subTest(source=source), self.assertRaises(ValueError): G['selected'](dict(self.env, CI_PIPELINE_SOURCE=source))
        for key in G['CONFLICTS']:
            with self.subTest(key=key), self.assertRaises(ValueError): G['selected'](dict(self.env, **{key: 'false'}))
        for source in ('api', 'pipeline', 'push', 'trigger'):
            with self.assertRaises(ValueError): G['selected'](dict(self.node_env, CI_PIPELINE_SOURCE=source))

    def test_schema_coverage_pair_compatibility_expansion_and_cycles_refuse(self):
        for change in ('missing', 'duplicate', 'partial', 'wrong-role', 'self', 'unknown', 'mode', 'expansion', 'schema', 'architecture'):
            candidate = copy.deepcopy(self.request)
            if change == 'missing': candidate['nodes'].pop()
            if change == 'duplicate': candidate['nodes'].append(copy.deepcopy(candidate['nodes'][0]))
            if change == 'partial': candidate['nodes'][1]['bindings'].pop()
            if change == 'wrong-role': candidate['nodes'][1]['bindings'][0]['artifact'] = 'image'
            if change == 'self': candidate['nodes'][1]['bindings'][0]['producer'] = 'stage1'
            if change == 'unknown': candidate['nodes'][1]['bindings'][0]['producer'] = 'missing'
            if change == 'mode': candidate['expectations']['members'][1]['mode'] = 'refresh'
            if change == 'expansion': candidate['expectations']['consumers'][0]['reason'] = 'Fixture $TOKEN'
            if change == 'schema': candidate['schema'] = True
            if change == 'architecture': candidate['expectations']['members'][1]['cpu'] = 'cortex-a53'
            with self.subTest(change=change), self.assertRaises(ValueError): G['selection'](candidate)
        # A cycle that is recipe-compatible (refresh Stage 1 pairs).
        candidate = copy.deepcopy(self.request)
        a = copy.deepcopy(candidate['expectations']['members'][1])
        a.update(id='stage1-other', variant='workstation', mode='refresh')
        candidate['expectations']['members'][1]['mode'] = 'refresh'
        candidate['expectations']['members'].append(a)
        next(c for c in candidate['expectations']['consumers'] if c['project'] == 'nest/stage1')['members'].append(a['id'])
        # CPU/variant matching would otherwise fail before the graph check.
        candidate['expectations']['members'][1]['variant'] = 'workstation'
        candidate['expectations']['members'][1]['platform'] = None
        # Distinct selection via a separate tool refresh cycle is impossible under
        # recipe identity; nevertheless the topological guard rejects cycles even
        # if future compatible() recipes permit them.
        candidate['nodes'][1]['bindings'] = [dict(base=r, producer=a['id'], artifact=r) for r in ('normal', 'debug')]
        candidate['nodes'].append(dict(member=a['id'], job_name='Candidate other', placement=None,
                                       bindings=[dict(base=r, producer='stage1', artifact=r) for r in ('normal', 'debug')]))
        # Keep selections unique while isolating the topological cycle guard.
        candidate['expectations']['members'][1]['variant'] = 'server'
        with patch.dict(G['B'], {'compatible': lambda *args: None}):
            with self.assertRaisesRegex(ValueError, 'cyclic graph'): G['selection'](candidate)

    def test_exact_native_lineage_failure_hidden_jobs_and_changed_result_refuse(self):
        for change in ('compiler', 'sha', 'root', 'active', 'lineage', 'failed-node', 'moved-node',
                       'missing-route', 'failed-route', 'loop', 'hidden', 'result', 'erased'):
            api = NativeGraph(copy.deepcopy(self.api.expected))
            if change == 'compiler': api.jobs[('nest/config', 601)]['name'] = 'Other'
            if change == 'sha': api.graph['expectations']['release'] = 'moved'
            if change == 'root': api.pipelines[650]['source'] = 'api'
            if change == 'active': api.jobs[('nest/config', 9011)]['id'] = 999
            if change == 'lineage': api.bridges[600][0]['downstream_pipeline']['id'] = 999
            if change == 'failed-node': api.jobs[('nest/config', 801)]['status'] = 'failed'
            if change == 'moved-node': api.bridges[650][0]['downstream_pipeline']['sha'] = 'f' * 40
            if change == 'missing-route': api.bridges[650] = []
            if change == 'failed-route': api.pipelines[850]['status'] = 'failed'
            if change == 'loop': api.bridges[1] = [dict(id=102)]
            if change == 'hidden': api.pipeline_jobs[1].append(dict(id=102, name='Other', status='failed', allow_failure=True))
            if change == 'result': api.result['expectations_digest'] = 'sha256:' + '0' * 64
            if change == 'erased': api.jobs[('nest/stage0', 101)]['erased_at'] = 'fixture'
            with self.subTest(change=change), self.assertRaises(ValueError): G['freeze_node'](self.node_env, api)
            self.assertFalse((self.f.checkout / 'release-inputs').exists())
            submitted = self.f.checkout / 'graph-node-input.json'
            if submitted.exists(): submitted.unlink()

    def test_failed_artifact_readback_and_changed_predecessor_cannot_route(self):
        original = Path.read_bytes
        def read(path): return b'changed' if path.name == 'graph.yml' else original(path)
        with patch.object(Path, 'read_bytes', read), self.assertRaises(ValueError): G['compile_graph'](self.request, self.env)
        count = 0
        def after(path):
            nonlocal count
            if path.endswith('/jobs/101/artifacts'):
                count += 1
                if count == 1: self.api.bridges[650][0]['id'] = 999
        self.api.after_get = after
        with self.assertRaises(ValueError): G['freeze_node'](self.node_env, self.api)
        self.assertFalse((self.f.checkout / 'release-inputs').exists())

    def test_real_cli_acquires_only_captured_gets_and_retains_bound_inputs(self):
        replies = {}
        original = self.api.get
        def get(path):
            result = original(path)
            replies[path] = result
            return result
        with patch.object(self.api, 'get', get): G['freeze_node'](self.node_env, self.api)
        # New job-local checkout prevents replay of already published output.
        import shutil
        shutil.rmtree(self.f.checkout / 'release-inputs')
        (self.f.checkout / 'graph-node-input.json').unlink()
        binary = self.f.root / 'bin'
        binary.mkdir()
        F['fake_glab'](binary / 'glab', replies)
        completed = subprocess.run([sys.executable, str(ROOT / 'scripts/nest-release-graph.py'), '--freeze-node'],
                                   env=dict(self.node_env, PATH=str(binary) + os.pathsep + self.node_env['PATH']), capture_output=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertEqual(R['load'](self.f.checkout / 'release-inputs/expectations.json')['members'][0]['bases'],
                         self.api.result['output']['artifacts'])
        self.assertNotIn(b'Traceback', completed.stderr)

    def test_transport_rejects_mutation_latest_and_foreign_paths(self):
        with patch('subprocess.run') as run:
            for path in ('projects/nest%2Fconfig/pipelines/latest', 'projects/nest%2Fconfig/jobs/1/retry',
                         'projects/nest%2Fconfig/jobs/1/artifacts/release-graph/other.json', 'https://fixture.invalid'):
                with self.assertRaises(ValueError): G['GitLab']().get(path)
            run.assert_not_called()

    def test_architectures_fanout_reuse_and_stage3_placement_are_explicit(self):
        for cpu in ('haswell', 'cortex-a53', 'sifive-u74'):
            candidate = copy.deepcopy(self.request)
            for member in candidate['expectations']['members']: member['cpu'] = cpu
            self.assertEqual(G['selection'](candidate)[3], ['stage0', 'stage1'])
        candidate = copy.deepcopy(self.request)
        sibling = copy.deepcopy(candidate['expectations']['members'][1])
        sibling.update(id='stage1-workstation', variant='workstation')
        candidate['expectations']['members'].append(sibling)
        next(c for c in candidate['expectations']['consumers'] if c['project'] == 'nest/stage1')['members'].append(sibling['id'])
        candidate['nodes'].append(dict(member=sibling['id'], job_name='Candidate haswell-workstation', placement=None,
                                       bindings=copy.deepcopy(candidate['nodes'][1]['bindings'])))
        G['compile_graph'](candidate, self.env)
        graph = R['load'](self.f.checkout / 'release-graph/graph.yml')
        self.assertEqual(graph['Freeze release inputs stage1']['needs'], ['Release node stage0'])
        self.assertEqual(graph['Freeze release inputs stage1-workstation']['needs'], ['Release node stage0'])
        candidate['nodes'] = candidate['nodes'][1:]
        candidate['nodes'][0]['bindings'] = []
        candidate['nodes'][1]['bindings'] = []
        next(c for c in candidate['expectations']['consumers'] if c['project'] == 'nest/stage0')['decision'] = 'reuse'
        self.assertNotIn('stage0', G['selection'](candidate)[1])
        full = request(F['MANIFEST']['fixture']()[0])
        node = next(n for n in full['nodes'] if n['member'] == 'stage3')
        with self.assertRaises(ValueError): G['selection'](full)
        node['placement'] = '/fixture/local/placement.json'
        self.assertIn('stage3', G['selection'](full)[1])
        for placement in ('relative', '/fixture/../escape', '/fixture/$EXPANSION'):
            node['placement'] = placement
            with self.assertRaises(ValueError): G['selection'](full)

    def completed(self):
        # Produce a Stage 1 result using the descendant's actually frozen input.
        G['freeze_node'](self.node_env, self.api)
        frozen = R['load'](self.f.checkout / 'release-inputs/expectations.json')
        self.api.pipelines[9050] = self.api.pipeline(9050, 'parent_pipeline', 'success')
        self.api.pipelines[2] = self.api.pipeline(2, 'pipeline', 'success', project='nest/stage1')
        self.api.bridges[650].append(self.api.bridge(661, 'Release node stage1', 650, 9050))
        self.api.bridges[9050] = [self.api.bridge(9060, 'Build frozen member', 9050, 2)]
        self.api.bridges[2] = []
        self.api.jobs[('nest/config', 9011)]['status'] = 'success'
        for project, pipeline, job, name in [('nest/stage1', 2, 102, 'Candidate haswell-server')]:
            self.api.jobs[(project, job)] = self.api.make_job(project, pipeline, job, name)
            self.api.jobs[(project, job)]['allow_failure'] = False
            self.api.pipeline_jobs[pipeline] = [self.api.jobs[(project, job)]]
        self.api.artifacts[('nest/config', 9011, 'release-inputs/expectations.json')] = frozen
        self.leaf = dict(schema=1, kind='nest_release_member_result', release=frozen['release'],
                         expectations_digest=R['digest'](frozen), executor_receipt=self.api.executor,
                         output=dict(member=copy.deepcopy(frozen['members'][0]), executor=frozen['executor'],
                                     producer=dict(project='nest/stage1', sha=frozen['sources']['nest/stage1'], pipeline=2, job=102),
                                     artifacts=dict(normal=F['MANIFEST']['image'](501), debug=F['MANIFEST']['image'](502))))
        self.api.artifacts[('nest/stage1', 102, 'release-results/stage1.json')] = self.leaf
        env = {k: v for k, v in self.node_env.items() if k not in ('RELEASE_GRAPH_NODE', 'RELEASE_GRAPH_MEMBER')}
        return dict(env, CI_PIPELINE_SOURCE='parent_pipeline', CI_PIPELINE_ID='650', CI_JOB_ID='699', CI_JOB_NAME='Accept release graph')

    def test_final_acceptance_checks_all_leaf_bytes_and_reopens_complete_rebuilt_manifest(self):
        env = self.completed()
        receipt = G['accept_graph'](env, self.api)
        self.assertEqual(receipt['rebuilt']['manifest']['candidate']['outputs'][1], self.leaf['output'])
        self.assertEqual(receipt['rebuilt']['manifest']['expectations']['members'][1]['bases'], self.api.result['output']['artifacts'])
        self.assertFalse(receipt['promotion_authorized'])
        self.assertEqual(R['load'](self.f.checkout / 'release-graph-acceptance/receipt.json'), receipt)
        with self.assertRaises(FileExistsError): G['accept_graph'](env, self.api)

    def test_self_consistent_leaf_cannot_change_projection_policy_sources_or_dependency_bases(self):
        env = self.completed()
        frozen = self.api.artifacts[('nest/config', 9011, 'release-inputs/expectations.json')]
        original, result = copy.deepcopy(frozen), copy.deepcopy(self.leaf)
        for change in ('policy', 'base', 'full-matrix'):
            if change == 'policy': frozen['consumers'][0]['reason'] = 'Changed unrelated policy'
            if change == 'base':
                frozen['members'][0]['bases']['normal'] = F['MANIFEST']['image'](800)
                self.leaf['output']['member'] = copy.deepcopy(frozen['members'][0])
            if change == 'full-matrix':
                full = copy.deepcopy(self.request['expectations'])
                full['members'][1] = copy.deepcopy(frozen['members'][0])
                frozen.clear(); frozen.update(full)
            # Pass the ordinary result/input digest contract. Final graph
            # acceptance must independently reconstruct the exact projection.
            self.leaf['expectations_digest'] = R['digest'](frozen)
            with self.subTest(change=change), self.assertRaisesRegex(ValueError, 'graph leaf escaped'):
                G['accept_graph'](env, self.api)
            self.assertFalse((self.f.checkout / 'release-graph-acceptance').exists())
            frozen.clear(); frozen.update(copy.deepcopy(original))
            self.leaf.clear(); self.leaf.update(copy.deepcopy(result))

    def test_green_leaf_with_wrong_dependency_base_or_executor_is_not_accepted(self):
        env = self.completed()
        for change in ('base', 'executor', 'digest', 'failed', 'input', 'lineage'):
            result = copy.deepcopy(self.leaf)
            frozen = self.api.artifacts[('nest/config', 9011, 'release-inputs/expectations.json')]
            original = copy.deepcopy(frozen)
            if change == 'base': self.leaf['output']['member']['bases']['normal'] = F['MANIFEST']['image'](800)
            if change == 'executor': self.leaf['executor_receipt'] = dict(self.api.executor, job=999)
            if change == 'digest': self.leaf['expectations_digest'] = 'sha256:' + '0' * 64
            if change == 'failed': self.api.pipelines[2]['status'] = 'failed'
            if change == 'input': frozen['consumers'][0]['reason'] = 'Changed unrelated closure'
            if change == 'lineage': self.api.bridges[600][0]['downstream_pipeline']['id'] = 999
            with self.subTest(change=change), self.assertRaises(ValueError): G['accept_graph'](env, self.api)
            self.assertFalse((self.f.checkout / 'release-graph-acceptance').exists())
            self.leaf.clear(); self.leaf.update(result)
            frozen.clear(); frozen.update(original)
            self.api.pipelines[2]['status'] = 'success'
            self.api.bridges[600][0]['downstream_pipeline']['id'] = 650


if __name__ == '__main__':
    unittest.main()
