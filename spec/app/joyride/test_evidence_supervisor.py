"""Independent infrastructure admission/orchestration contracts, not app tests."""
import copy
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('supervisor', ROOT / 'files/app/joyride/evidence_supervisor.py')
assert spec is not None and spec.loader is not None
supervisor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(supervisor)


def archive(data, uid=0, mode=0o644, symlink=False):
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode='w') as output:
        info = tarfile.TarInfo('source.py')
        info.uid, info.mode, info.size = uid, mode, len(data)
        if symlink:
            info.type, info.linkname, info.size = tarfile.SYMTYPE, 'elsewhere', 0
        output.addfile(info, None if symlink else io.BytesIO(data))
    return buffer.getvalue()


class SupervisorTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.root.chmod(0o700)
        self.addCleanup(self.temporary.cleanup)
        self.image = {'Os': 'linux', 'Architecture': 'amd64', 'RepoDigests': [supervisor.IMAGE],
                      'Config': {'Entrypoint': supervisor.ENTRYPOINT, 'Labels': {
                          'org.opencontainers.image.revision': supervisor.SOURCE,
                          'org.opencontainers.image.source': 'https://gitlab.joyfullee.me/joy/joyride'}}}
        self.current = {'metadata': {'uid': 'cron-uid', 'resourceVersion': '12'},
                        'spec': {'suspend': True, 'concurrencyPolicy': 'Forbid'}}

    def runner(self, args, data=None, timeout=60):
        if args[1:3] == ['image', 'inspect']:
            return json.dumps([self.image]).encode()
        if args[1] == 'create':
            return b'a' * 64
        if args[1] == 'cp':
            return archive(b'reviewed bytes')
        return b''

    def test_admission_reads_actual_bytes_and_removes_stopped_container(self):
        import hashlib
        with patch.object(supervisor, 'HASHES', {'/fixed.py': hashlib.sha256(b'reviewed bytes').hexdigest()}), \
                patch.object(supervisor, 'run', side_effect=self.runner) as run:
            self.assertEqual(supervisor.admit()['image'], supervisor.IMAGE)
        self.assertEqual(run.call_args.args[0], ['podman', 'rm', 'a' * 64])

    def test_mismatched_source_bytes_refused_and_container_removed(self):
        with patch.object(supervisor, 'run', side_effect=self.runner) as run:
            with self.assertRaises(ValueError):
                supervisor.admit()
        self.assertEqual(run.call_args.args[0], ['podman', 'rm', 'a' * 64])

    def test_mutable_entrypoint_command_revision_or_repository_refused(self):
        for change in ('entrypoint', 'command', 'revision', 'repository', 'platform'):
            image = copy.deepcopy(self.image)
            if change == 'entrypoint':
                image['Config']['Entrypoint'] = ['python', 'caller.py']
            elif change == 'command':
                image['Config']['Cmd'] = ['unreviewed']
            elif change == 'revision':
                image['Config']['Labels']['org.opencontainers.image.revision'] = '0' * 40
            elif change == 'repository':
                image['RepoDigests'] = ['other@sha256:' + '0' * 64]
            else:
                image['Architecture'] = 'arm64'
            with self.subTest(change=change), patch.object(supervisor, 'run', side_effect=lambda args, **kwargs:
                    json.dumps([image]).encode() if args[1:3] == ['image', 'inspect'] else b''):
                with self.assertRaises(ValueError):
                    supervisor.admit()

    def test_source_symlink_writability_and_nonroot_ownership_refused(self):
        for data in (archive(b'bad', symlink=True), archive(b'bad', mode=0o666), archive(b'bad', uid=1000)):
            def run(args, **kwargs):
                return data if args[1] == 'cp' else self.runner(args, **kwargs)
            with patch.object(supervisor, 'run', side_effect=run):
                with self.assertRaises(ValueError):
                    supervisor.admit()

    def test_container_mounts_exclude_operator_authority_and_unsigned_key(self):
        args = supervisor.container_args(self.root, self.root / 'identity/kubeconfig', False)
        self.assertIn('--read-only', args)
        self.assertIn('--cap-drop=ALL', args)
        self.assertIn('--http-proxy=false', args)
        self.assertNotIn('/credentials/signing.key', ' '.join(args))
        mounts = [args[i + 1] for i, arg in enumerate(args) if arg == '--mount']
        self.assertEqual(len(mounts), 3)
        self.assertTrue(all('socket' not in mount and '/.kube/' not in mount for mount in mounts))
        self.assertEqual(args[-2:], [supervisor.IMAGE, 'collect'])

    def test_signed_container_mounts_only_session_key_read_only(self):
        args = supervisor.container_args(self.root, self.root / 'identity/kubeconfig', True)
        self.assertIn('type=bind,src=' + str(self.root / 'signing.key') + ',dst=/credentials/signing.key,ro=true', args)

    def test_cron_patch_uses_uid_version_and_prior_state_fences(self):
        before = copy.deepcopy(self.current)
        before['spec']['suspend'] = False
        with patch.object(supervisor.identity, 'command', return_value=self.current) as command:
            supervisor.switch_cron(before, True)
        args = command.call_args.args[0]
        values = json.loads(args[args.index('-p') + 1])
        self.assertEqual([value['op'] for value in values], ['test', 'test', 'test', 'replace'])
        self.assertEqual(values[1]['value'], '12')
        self.assertEqual(values[2]['value'], False)
        self.assertEqual(values[3], {'op': 'replace', 'path': '/spec/suspend', 'value': True})

    def quiet(self, active=False, journal=None, jobs=None, current=None):
        observed = copy.deepcopy(current or self.current)
        if active:
            observed['status'] = {'active': [{'name': 'running'}]}
        with patch.object(supervisor, 'cron', return_value=observed), \
                patch.object(supervisor.identity, 'command', side_effect=[{'items': jobs or []},
                    {'data': journal if journal is not None else {'active': 'null'}}]):
            supervisor.quiescent(self.current)

    def test_quiescence_accepts_actual_empty_journal(self):
        self.quiet()

    def test_quiescence_refuses_active_job_and_nonempty_journal(self):
        with self.assertRaises(ValueError):
            self.quiet(active=True)
        with self.assertRaises(ValueError):
            self.quiet(journal={'active': '{"request":"in-progress"}'})
        with self.assertRaises(ValueError):
            self.quiet(jobs=[{'metadata': {'ownerReferences': [{'uid': 'cron-uid'}]}, 'status': {}}])

    def test_quiescence_refuses_concurrent_spec_or_uid_change(self):
        for change in ('uid', 'spec'):
            altered = copy.deepcopy(self.current)
            if change == 'uid':
                altered['metadata']['uid'] = 'replacement'
            else:
                altered['spec']['concurrencyPolicy'] = 'Allow'
            with self.assertRaises(ValueError):
                self.quiet(current=altered)

    def test_incomplete_session_blocks_replacement_before_any_mutation(self):
        (self.root / 'sessions').mkdir(mode=0o700)
        (self.root / 'sessions/unfinished').mkdir(mode=0o700)
        with patch.object(supervisor, 'STATE', self.root), patch.object(supervisor, 'cron') as cron:
            with self.assertRaises(ValueError):
                supervisor.collect(10760, 'sha256:' + 'a' * 64, 'b' * 40, False)
        cron.assert_not_called()

    def candidate(self):
        now = int(time.time())
        return {'schema': 1, 'kind': 'joyride-installed-test-v1',
                'pipeline_url': 'https://gitlab.joyfullee.me/joy/joyride/-/pipelines/10760',
                'repository': 'registry.gitlab.joyfullee.me/joy/joyride/app',
                'digest': 'sha256:' + 'a' * 64, 'source_head': 'b' * 40,
                'namespace': 'test', 'deployment': 'joyride-test', 'observed_at': now, 'expires_at': now + 900,
                'checks': ['https_readiness', 'session_csrf', 'disabled_billing',
                           'private_route_photo_gpx', 'photo_only', 'basemap_range']}

    def receipt(self, data):
        path = self.root / 'receipt.json'
        path.write_text(json.dumps(data))
        path.chmod(0o600)
        return path

    def verify(self, data, signed=False):
        return supervisor.verify_receipt(self.receipt(data), signed, 10760, 'sha256:' + 'a' * 64, 'b' * 40)

    def test_unsigned_collection_is_not_a_signature_envelope(self):
        candidate = self.candidate()
        result = self.verify({'kind': 'unsigned-installed-test-collection', 'candidate': candidate})
        self.assertEqual(result['candidate'], candidate)
        with self.assertRaises(ValueError):
            self.verify({'payload': candidate, 'signature': 'a' * 128})

    def test_expired_wrong_artifact_or_missing_checks_refused(self):
        for key, value in [('observed_at', 1), ('digest', 'sha256:' + 'c' * 64),
                           ('namespace', 'joyride'), ('checks', [])]:
            candidate = self.candidate()
            candidate[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.verify({'kind': 'unsigned-installed-test-collection', 'candidate': candidate})

    def test_openssl_independently_verifies_real_disposable_signature(self):
        key = subprocess.check_output(['openssl', 'genpkey', '-algorithm', 'ED25519', '-outform', 'DER'])
        public = subprocess.check_output(['openssl', 'pkey', '-inform', 'DER', '-pubout', '-outform', 'DER'], input=key)
        private = self.root / 'disposable.der'
        private.write_bytes(key)
        private.chmod(0o600)
        payload = self.candidate()
        message = self.root / 'disposable-message'
        message.write_bytes(b'joyride-installed-test-v1\x00' + supervisor.canonical(payload))
        signature = subprocess.check_output(['openssl', 'pkeyutl', '-sign', '-keyform', 'DER',
                                             '-inkey', str(private), '-rawin', '-in', str(message)])
        with patch.object(supervisor, 'PUBLIC', public[-32:].hex()):
            self.verify({'payload': payload, 'signature': signature.hex()}, signed=True)

    def test_wrong_signature_does_not_verify(self):
        with self.assertRaises(ValueError):
            self.verify({'payload': self.candidate(), 'signature': '00' * 64}, signed=True)

    def test_protected_file_refuses_link_or_permissions(self):
        path = self.receipt({'fixture': True})
        path.chmod(0o644)
        with self.assertRaises(ValueError):
            supervisor.protected(path, os.geteuid(), 0o600)
        path.chmod(0o600)
        os.link(path, self.root / 'hardlink')
        with self.assertRaises(ValueError):
            supervisor.protected(path, os.geteuid(), 0o600)


    def workflow(self, fail=False):
        (self.root / 'sessions').mkdir(mode=0o700)
        (self.root / 'gitlab-token').write_text('disposable-fixture-token')
        (self.root / 'gitlab-token').chmod(0o600)
        current = copy.deepcopy(self.current)
        current['spec']['suspend'] = False
        target = {'image': 'registry.gitlab.joyfullee.me/joy/joyride/app@sha256:' + 'a' * 64,
                  'deployment_uid': 'fixture-deployment', 'generation': 16, 'delivery_id': 'fixture-delivery'}
        calls = []

        class Authority:
            def __init__(self, directory, pod):
                self.config = directory / 'kubeconfig'

            def provision(self):
                self.config.write_text('{}')
                self.config.chmod(0o600)

            def verify(self):
                return 16

            def revoke(self):
                calls.append('revoke')
                self.config.unlink()

        def switch(before, suspended):
            calls.append('suspend' if suspended else 'resume')
            current['spec']['suspend'] = suspended
            return copy.deepcopy(current)

        def run(args, **kwargs):
            if args[1] == 'run':
                calls.append('collect')
                if fail:
                    raise ValueError('synthetic_runtime_failure')
                session, = (self.root / 'sessions').iterdir()
                candidate = self.candidate()
                candidate.update({key: target[key] for key in ('deployment_uid', 'generation', 'delivery_id')})
                receipt = session / 'output/receipt.json'
                receipt.write_text(json.dumps({'kind': 'unsigned-installed-test-collection', 'candidate': candidate}))
                receipt.chmod(0o600)
            return b''

        with patch.object(supervisor, 'STATE', self.root), \
                patch.object(supervisor, 'cron', side_effect=lambda: copy.deepcopy(current)), \
                patch.object(supervisor, 'switch_cron', side_effect=switch), \
                patch.object(supervisor, 'quiescent'), \
                patch.object(supervisor.identity, 'Identity', Authority), \
                patch.object(supervisor.identity, 'bind_target', return_value=target), \
                patch.object(supervisor.identity, 'command', return_value={'items': [
                    {'metadata': {'name': 'joyride-test-fixture-pod'}}]}), \
                patch.object(supervisor, 'run', side_effect=run):
            if fail:
                with self.assertRaises(ValueError):
                    supervisor.collect(10760, 'sha256:' + 'a' * 64, 'b' * 40, False)
            else:
                supervisor.collect(10760, 'sha256:' + 'a' * 64, 'b' * 40, False)
        return calls, current

    def test_success_revokes_and_cleans_credentials_before_resuming(self):
        calls, current = self.workflow()
        self.assertEqual(calls, ['suspend', 'collect', 'revoke', 'resume'])
        self.assertFalse(current['spec']['suspend'])
        session, = (self.root / 'sessions').iterdir()
        self.assertTrue((session / 'complete.json').is_file())
        for name in ('identity/kubeconfig', 'kubeconfig', 'gitlab/config.yml', 'signing.key'):
            self.assertFalse((session / name).exists())

    def test_runtime_failure_preserves_exact_journal_and_prevents_auto_resume(self):
        calls, current = self.workflow(fail=True)
        self.assertEqual(calls, ['suspend', 'collect'])
        self.assertTrue(current['spec']['suspend'])
        session, = (self.root / 'sessions').iterdir()
        self.assertTrue((session / 'collection-started.json').is_file())
        self.assertFalse((session / 'complete.json').exists())


if __name__ == '__main__':
    unittest.main()
