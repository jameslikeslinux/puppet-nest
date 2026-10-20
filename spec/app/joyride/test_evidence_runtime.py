"""Real rootless container isolation/key canaries; disposable keys, no live mounts."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[3]


class EvidenceRuntime(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.image = 'localhost/joyride-evidence-fixture:' + uuid.uuid4().hex
        build = subprocess.run([
            'podman', 'build', '--dns=172.22.4.3',
            '-f', str(ROOT / 'files/app/joyride/Containerfile.evidence'),
            '-t', cls.image, str(ROOT / 'files/app/joyride')],
            capture_output=True, text=True, timeout=240, check=False)
        if build.returncode:
            raise AssertionError('Evidence fixture image build failed: ' + build.stderr[-4000:])
        cls.addClassCleanup(subprocess.run, ['podman', 'rmi', cls.image],
                            capture_output=True, check=False, timeout=60)

    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.path = Path(self.folder.name)
        self.path.chmod(0o700)
        self.volume = 'joyride-evidence-keys-' + uuid.uuid4().hex
        subprocess.run(['podman', 'volume', 'create', self.volume],
                       capture_output=True, text=True, timeout=30, check=True)
        self.addCleanup(subprocess.run, ['podman', 'volume', 'rm', self.volume],
                        capture_output=True, check=True, timeout=30)
        initialized = self.run_image('-c', 'import os; os.chmod("/keys", 0o700)',
                                     options=('--entrypoint=/opt/joyride-evidence/venv/bin/python',))
        self.assertEqual(initialized.returncode, 0, initialized.stderr)

    def run_image(self, *args, options=()):
        # The CI client and remote Podman engine do not share /tmp. Transfer
        # disposable fixtures through cp and an engine-owned volume instead of
        # assuming any client path exists on the engine host.
        container = 'joyride-evidence-run-' + uuid.uuid4().hex
        subprocess.run([
            'podman', 'create', '--name', container, '--network=none', '--read-only',
            '--cap-drop=ALL', '--security-opt=no-new-privileges',
            '--pids-limit=64', '--memory=256m', '--cpus=1',
            '--tmpfs=/scratch:rw,noexec,nosuid,nodev,size=16m,mode=700',
            '-v', self.volume + ':/keys:rw', *options, self.image, *args],
            capture_output=True, text=True, timeout=60, check=True)
        try:
            subprocess.run(['podman', 'cp', str(self.path) + '/.', container + ':/keys'],
                           capture_output=True, text=True, timeout=30, check=True)
            result = subprocess.run(['podman', 'start', '--attach', container],
                                    capture_output=True, text=True, timeout=60, check=False)
            subprocess.run(['podman', 'cp', container + ':/keys/.', str(self.path)],
                           capture_output=True, text=True, timeout=30, check=True)
            return result
        finally:
            subprocess.run(['podman', 'rm', '-f', container],
                           capture_output=True, text=True, timeout=30, check=True)

    def test_real_generation_roundtrip_and_no_private_output(self):
        created = self.run_image('key', 'create', '/keys/generation')
        self.assertEqual(created.returncode, 0, created.stderr)
        public = json.loads(created.stdout)
        inspected = self.run_image('key', 'inspect', '/keys/generation')
        self.assertEqual(inspected.returncode, 0, inspected.stderr)
        self.assertEqual(json.loads(inspected.stdout), public)
        private = (self.path / 'generation/signing.key').read_bytes()
        self.assertEqual(len(private), 32)
        self.assertNotIn(private.hex(), created.stdout + inspected.stdout)
        refused = self.run_image('key', 'create', '/keys/generation')
        self.assertEqual(refused.returncode, 1)
        self.assertEqual((self.path / 'generation/signing.key').read_bytes(), private)
        self.assertNotIn('Traceback', refused.stderr)

    def test_caller_pythonpath_and_working_directory_cannot_replace_source(self):
        # Attacker-controlled module is mounted only where a naive Python launch
        # would import it. Isolated mode + fixed root-owned source must ignore it.
        (self.path / 'installed_test_producer.py').write_text('raise RuntimeError("injected_module_executed")\n')
        result = self.run_image('key', 'create', '/keys/generation', options=(
            '--env=PYTHONPATH=/keys', '--env=PYTHONHOME=/keys', '--workdir=/keys'))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)['algorithm'], 'Ed25519')
        self.assertNotIn('injected_module_executed', result.stderr)

    def test_network_failure_emits_no_signed_receipt(self):
        created = self.run_image('key', 'create', '/keys/generation')
        self.assertEqual(created.returncode, 0, created.stderr)
        result = self.run_image('collect', '--pipeline', '10665', '--digest', 'sha256:' + 'a' * 64,
                                '--source-head', 'b' * 40, '--signing-key', '/keys/generation/signing.key',
                                '--output', '/keys/receipt.json')
        self.assertEqual(result.returncode, 1)
        self.assertFalse((self.path / 'receipt.json').exists())
        self.assertNotIn('signature', result.stdout)
        self.assertNotIn('Traceback', result.stderr)

    def test_caller_path_cannot_substitute_gitlab_or_kubernetes_tools(self):
        executable = self.path / 'glab'
        executable.write_text('#!/bin/sh\n/usr/bin/touch /keys/injected-tool-ran\nexit 1\n')
        executable.chmod(0o755)
        result = self.run_image('collect', '--collect-only', '--pipeline', '10665',
                                '--digest', 'sha256:' + 'a' * 64, '--source-head', 'b' * 40,
                                '--output', '/keys/receipt.json', options=('--env=PATH=/keys',))
        self.assertEqual(result.returncode, 1)
        self.assertFalse((self.path / 'injected-tool-ran').exists())
        self.assertFalse((self.path / 'receipt.json').exists())

    def test_image_has_fixed_entrypoint_and_only_root_owned_source(self):
        inspected = subprocess.run(['podman', 'image', 'inspect', self.image],
                                   capture_output=True, text=True, timeout=30, check=True)
        config = json.loads(inspected.stdout)[0]['Config']
        self.assertEqual(config['Entrypoint'], [
            '/opt/joyride-evidence/venv/bin/python', '-I', '-B', '/opt/joyride-evidence/runtime.py'])
        result = self.run_image('-c',
            'from pathlib import Path; import os; '
            'p=Path("/opt/joyride-evidence/source"); '
            'assert {f.name for f in p.iterdir()} == {"evidence_key.py", "installed_test_producer.py", "installed_test_probes.py"}; '
            'assert all(f.stat().st_uid == 0 and not f.stat().st_mode & 0o022 for f in p.iterdir()); '
            'assert not os.access("/opt/joyride-evidence/source", os.W_OK)',
            options=('--entrypoint=/opt/joyride-evidence/venv/bin/python',))
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
