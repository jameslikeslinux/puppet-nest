"""Real Podman lifecycle regression tests; disposable owner-labelled fixtures only."""
import io
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import unittest
import uuid
from unittest.mock import patch

import fixture_resources as resources
import test_production_ops as ops


class FixtureLifecycle(unittest.TestCase):
    def assert_absent(self, scope, instance=None):
        filters = ['--filter', f'label={resources.OWNER_LABEL}={scope}']
        if instance:
            filters += ['--filter', f'label={resources.INSTANCE_LABEL}={instance}']
        self.assertEqual(resources.command('ps', '-aq', *filters).strip(), '')
        self.assertEqual(resources.command('network', 'ls', '-q', *filters).strip(), '')

    def exercise(self, failure=None):
        class Probe(ops.OpsFixture, unittest.TestCase):
            allow_loopback = True

            def test_probe(self):
                self.assertEqual(self.request()[0], 401)
                if failure == 'assertion':
                    self.fail('Injected assertion failure')

        original = ops.run

        def injected(*args):
            result = original(*args)
            # Creation completed remotely, but the caller sees a failure/timeout.
            if args[:2] == ('podman', 'create') and args[args.index('--name') + 1] == Probe.container:
                if failure == 'setup':
                    raise RuntimeError('Injected setup subprocess failure')
                if failure == 'timeout':
                    raise subprocess.TimeoutExpired('synthetic fixture create', 120)
            return result

        with patch.object(ops, 'run', side_effect=injected):
            result = unittest.TextTestRunner(stream=io.StringIO()).run(
                unittest.defaultTestLoader.loadTestsFromTestCase(Probe))
        self.assertEqual(len(result.errors), int(failure in ('setup', 'timeout')))
        self.assertEqual(len(result.failures), int(failure == 'assertion'))
        self.assert_absent(Probe.resources.owner, Probe.resources.instance)

    def test_success(self):
        self.exercise()

    def test_assertion_failure(self):
        self.exercise('assertion')

    def test_partial_setup_subprocess_failure(self):
        self.exercise('setup')

    def test_partial_setup_subprocess_timeout(self):
        self.exercise('timeout')

    def test_interrupted_process_uses_separate_job_cleanup(self):
        # A concurrent fixture with another owner must survive both cleanups.
        sentinel = 'local-' + uuid.uuid4().hex
        name = 'joyride-lifecycle-sentinel-' + uuid.uuid4().hex[:12]
        resources.command('network', 'create', '--internal', '--label',
                          f'{resources.OWNER_LABEL}={sentinel}', name)
        try:
            for sig in (signal.SIGTERM, signal.SIGKILL):
                with self.subTest(signal=sig.name):
                    env = dict(os.environ, CI='true', CI_PROJECT_ID='3', CI_JOB_ID=str(uuid.uuid4().int))
                    scope = f"ci-3-{env['CI_JOB_ID']}"
                    # Pause after the exact historical partial-setup stage: running
                    # upstream plus never-started namespace-dependent nginx.
                    script = '''
import time, unittest
import test_production_ops as ops
original = ops.run
class Probe(ops.OpsFixture, unittest.TestCase): pass
def run(*args):
    result = original(*args)
    if args[:2] == ('podman', 'create') and args[args.index('--name') + 1] == Probe.container:
        print('fixture-ready', flush=True)
        time.sleep(120)
    return result
ops.run = run
Probe.setUpClass()
'''
                    child = subprocess.Popen([sys.executable, '-u', '-c', script], env=env,
                                             cwd=Path(__file__).parent, stdout=subprocess.PIPE,
                                             stderr=subprocess.DEVNULL, text=True)
                    assert child.stdout is not None
                    try:
                        import select
                        ready, _, _ = select.select([child.stdout], [], [], 100)
                        self.assertTrue(ready, 'Fixture setup readiness timed out')
                        self.assertEqual(child.stdout.readline().strip(), 'fixture-ready')
                        child.send_signal(sig)
                        self.assertEqual(child.wait(timeout=15), -sig)
                        # Prove the historical leak actually occurred, before
                        # the separate cleanup phase repairs it.
                        fixture_filter = ('--filter', f'label={resources.OWNER_LABEL}={scope}')
                        self.assertEqual(len(resources.command('ps', '-aq', *fixture_filter).split()), 2)
                        self.assertEqual(len(resources.command('network', 'ls', '-q', *fixture_filter).split()), 1)
                        # Same standalone command as GitLab after_script, new process.
                        result = subprocess.run([sys.executable, str(Path(resources.__file__).resolve()), 'cleanup-ci'],
                                                env=env, capture_output=True, text=True, timeout=120)
                        self.assertEqual(result.returncode, 0, result.stderr)
                        self.assert_absent(scope)
                        self.assertTrue(resources.command('network', 'inspect', name))
                    finally:
                        if child.poll() is None:
                            child.kill()
                            child.wait(timeout=15)
                        child.stdout.close()
                        resources.cleanup(scope)
        finally:
            resources.cleanup(sentinel)

    def test_removal_failure_timeout_retry_and_residue_reporting(self):
        for failure in ('once', 'timeout', 'persistent'):
            with self.subTest(failure=failure):
                scope = 'local-' + uuid.uuid4().hex
                name = 'joyride-lifecycle-removal-' + uuid.uuid4().hex[:12]
                cid = resources.command('create', '--name', name, '--network', 'none', '--label',
                                        f'{resources.OWNER_LABEL}={scope}', ops.PYTHON,
                                        'python', '-c', 'pass').strip()
                original = resources.subprocess.run
                attempts = []

                def injected(args, **kwargs):
                    if args[1] == 'rm' and cid in args:
                        attempts.append(1)
                        if failure == 'persistent' or len(attempts) == 1:
                            if failure == 'timeout':
                                raise subprocess.TimeoutExpired('synthetic fixture rm', 30)
                            return subprocess.CompletedProcess(args, 125, '', 'Injected removal failure')
                    return original(args, **kwargs)

                try:
                    with patch.object(resources.subprocess, 'run', side_effect=injected):
                        if failure == 'persistent':
                            with self.assertRaisesRegex(RuntimeError, 'cleanup residue'):
                                resources.cleanup(scope)
                        else:
                            resources.cleanup(scope)
                            self.assert_absent(scope)
                    if failure == 'persistent':
                        self.assertEqual(json.loads(resources.command('inspect', cid))[0]['Id'], cid)
                finally:
                    resources.cleanup(scope)
                self.assert_absent(scope)


if __name__ == '__main__':
    unittest.main(verbosity=2)
