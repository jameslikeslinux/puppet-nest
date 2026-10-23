#!/usr/bin/env python3
"""Member-scoped freezer compatibility; offline real binder/discovery/bootstrap."""

import copy
from pathlib import Path
import runpy
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
B = runpy.run_path(str(ROOT / 'scripts/nest-release-bind.py'))
F = runpy.run_path(str(ROOT / 'spec/files/nest_release_bind_test.py'))
D = runpy.run_path(str(ROOT / 'spec/files/nest_release_discover_test.py'))
E = runpy.run_path(str(ROOT / 'spec/files/nest_executor_bootstrap_test.py'))


class InputNamesTest(unittest.TestCase):
    def test_exact_names_and_invalid_members(self):
        self.assertEqual(B['input_job_names']('stage1-server'),
                         ('Freeze release inputs', 'Freeze release inputs stage1-server'))
        for member in ('', 'UPPER', '../member', 'a b', 'member\n', '$MEMBER', 'a' * 129, None, True):
            with self.subTest(member=member), self.assertRaises(ValueError):
                B['input_job_names'](member)

    def test_binder_accepts_scoped_producer_without_changing_source_or_bytes(self):
        api = F['FakeGitLab']()
        before = copy.deepcopy(api.artifacts)
        expected, _ = B['bind'](api.request, api)
        api.jobs[('nest/config', 801)]['name'] = 'Freeze release inputs stage0'
        actual, receipt = B['bind'](api.request, api)
        self.assertEqual(actual, expected)
        self.assertEqual(api.artifacts, before)
        self.assertIn('Freeze release inputs stage0',
                      [row['job']['name'] for row in receipt['predecessors']])

    def test_binder_refuses_wrong_member_patterns_whitespace_and_source(self):
        for name in ('Freeze release inputs stage1', 'Freeze release inputs stage0-extra',
                     'Freeze release inputs stage0\n', 'Freeze release inputs  stage0',
                     'Freeze release inputs $MEMBER', 'Freeze release inputs: stage0'):
            api = F['FakeGitLab']()
            api.jobs[('nest/config', 801)]['name'] = name
            with self.subTest(name=name), self.assertRaises(ValueError): B['bind'](api.request, api)
        api = F['FakeGitLab']()
        job = api.jobs[('nest/config', 801)]
        job['name'] = 'Freeze release inputs stage0'
        job['commit']['id'] = 'f' * 40
        with self.assertRaises(ValueError): B['bind'](api.request, api)

    def test_discovery_selects_only_member_freezer_while_siblings_run(self):
        api = D['NativeGitLab']()
        api.jobs[('nest/config', 801)]['name'] = 'Freeze release inputs stage0'
        sibling = dict(api.jobs[('nest/config', 801)], id=802, name='Freeze release inputs stage1', status='running')
        get = api.get
        def read(path):
            if '/pipelines/800/jobs?' in path:
                return B['RELEASE']['canonical']([api.jobs[('nest/config', 801)], sibling])
            return get(path)
        with patch.object(api, 'get', read): result = D['D']['discover'](api.request, api)
        self.assertEqual(result['binding_request']['producers']['upstream']['input_job'], 801)
        self.assertEqual(result['edges']['upstream']['input_job']['name'], 'Freeze release inputs stage0')

    def test_discovery_rejects_legacy_scoped_pair_and_duplicate_not_latest(self):
        for name in ('Freeze release inputs', 'Freeze release inputs stage0'):
            api = D['NativeGitLab']()
            api.jobs[('nest/config', 801)]['name'] = 'Freeze release inputs stage0'
            duplicate = dict(api.jobs[('nest/config', 801)], id=802, name=name)
            get = api.get
            def read(path):
                if '/pipelines/800/jobs?' in path:
                    return B['RELEASE']['canonical']([api.jobs[('nest/config', 801)], duplicate])
                return get(path)
            with patch.object(api, 'get', read), self.subTest(name=name), self.assertRaises(ValueError):
                D['D']['discover'](api.request, api)

    def test_discovery_refuses_name_changed_between_listing_and_job_read(self):
        api = D['NativeGitLab']()
        get = api.get
        def read(path):
            raw = get(path)
            if '/pipelines/800/jobs?' in path:
                api.jobs[('nest/config', 801)]['name'] = 'Freeze release inputs stage0'
            return raw
        with patch.object(api, 'get', read), self.assertRaises(ValueError):
            D['D']['discover'](api.request, api)

    def test_bootstrap_scoped_member_keeps_distinct_source_and_exact_receipts(self):
        fixture = E['ExecutorBootstrapTest']()
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        before = fixture.acquire()
        fixture.api.jobs[('nest/config', 801)]['name'] = 'Freeze release inputs tool'
        result = fixture.acquire()
        self.assertEqual(result['successor'], before['successor'])
        self.assertEqual(result['predecessor']['expectations'], before['predecessor']['expectations'])
        self.assertNotEqual(result['successor']['source'],
                            result['predecessor']['expectations']['sources']['nest/config'])
        fixture.api.jobs[('nest/config', 801)]['name'] = 'Freeze release inputs another-tool'
        with self.assertRaises(ValueError): fixture.acquire()


if __name__ == '__main__':
    unittest.main()
