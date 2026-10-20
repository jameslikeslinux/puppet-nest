"""Publication boundaries with fake registry/engine; real image isolation is separate."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
SPEC = importlib.util.spec_from_file_location(
    'evidence_release', ROOT / 'files/app/joyride/release_evidence_runtime.py')
assert SPEC is not None and SPEC.loader is not None
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)
SHA = 'a' * 40
DIGEST = 'sha256:' + 'b' * 64
ENV = {'CI_PROJECT_PATH': 'nest/config', 'CI_PROJECT_ID': '3',
       'CI_REGISTRY': release.REGISTRY, 'CI_COMMIT_BRANCH': 'main',
       'CI_DEFAULT_BRANCH': 'main', 'CI_COMMIT_REF_PROTECTED': 'true',
       'CI_PIPELINE_SOURCE': 'push', 'CI_COMMIT_SHA': SHA,
       'CI_PIPELINE_ID': '123', 'CI_JOB_ID': '456',
       'CI_REGISTRY_USER': 'fixture', 'CI_REGISTRY_PASSWORD': 'disposable-not-a-credential'}


class EvidenceRelease(unittest.TestCase):
    def setUp(self):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.output = Path(folder.name) / 'release.json'
        self.calls = []
        self.image = {'RepoDigests': [release.REPOSITORY + '@' + DIGEST],
                      'Os': 'linux', 'Architecture': 'amd64',
                      'Config': {'Labels': {'org.opencontainers.image.revision': SHA},
                                 'Entrypoint': release.ENTRYPOINT}}
        self.failure = None
        self.dirty = False
        self.head = SHA

    def engine(self, args, **kwargs):
        self.calls.append((args, kwargs))
        if args[0] == 'git':
            return self.head if 'rev-parse' in args else (' M tracked' if self.dirty else '')
        operation = args[1]
        if self.failure == operation:
            raise RuntimeError('fixture engine failure')
        if operation == 'build':
            context = Path(args[-1])
            self.assertEqual(sorted(p.name for p in context.iterdir()), sorted(release.FILES))
            self.assertNotIn('--secret', args)
            self.assertNotIn('--volume', args)
        if operation == 'push':
            Path(args[args.index('--digestfile') + 1]).write_text(DIGEST)
        if operation == 'image':
            return json.dumps([self.image])
        return ''

    def publish(self):
        with patch.object(release, 'run', side_effect=self.engine):
            return release.publish(ENV, self.output)

    def test_release_requires_protected_main_push_exact_project_and_full_pipeline(self):
        cases = {'CI_PROJECT_PATH': 'joy/joyride', 'CI_PROJECT_ID': '82',
                 'CI_REGISTRY': 'other.invalid', 'CI_COMMIT_BRANCH': 'feature',
                 'CI_DEFAULT_BRANCH': 'other', 'CI_COMMIT_REF_PROTECTED': 'false',
                 'CI_PIPELINE_SOURCE': 'merge_request_event', 'CI_COMMIT_SHA': 'moving',
                 'CI_PIPELINE_ID': '0', 'CI_JOB_ID': '-1', 'CI_COMMIT_TAG': 'v1',
                 'EXECUTOR_ONLY': 'true', 'BUILD': 'haswell', 'CI_REGISTRY_PASSWORD': ''}
        for key, value in cases.items():
            with self.subTest(key=key), patch.object(release, 'run') as run:
                env = dict(ENV, **{key: value})
                with self.assertRaises(ValueError):
                    release.publish(env, self.output)
                run.assert_not_called()

    def test_exact_registry_readback_before_sanitized_receipt_and_private_auth_cleanup(self):
        receipt = self.publish()
        self.assertEqual(json.loads(self.output.read_text()), receipt)
        self.assertEqual(receipt['image'], release.REPOSITORY + '@' + DIGEST)
        self.assertEqual(receipt['source_head'], SHA)
        self.assertEqual(set(receipt['source_sha256']), set(release.FILES))
        operations = [args[1] for args, _ in self.calls if args[0] == 'podman']
        self.assertEqual(operations, ['login', 'build', 'push', 'pull', 'image', 'rmi'])
        login, options = next(c for c in self.calls if c[0][1] == 'login')
        self.assertEqual(options['input'], ENV['CI_REGISTRY_PASSWORD'])
        self.assertNotIn(ENV['CI_REGISTRY_PASSWORD'], str(login))
        self.assertNotIn(ENV['CI_REGISTRY_PASSWORD'], self.output.read_text())
        self.assertFalse(Path(login[login.index('--authfile') + 1]).parent.exists())

    def test_dirty_or_wrong_checkout_is_rejected_before_registry(self):
        for dirty, head in [(True, SHA), (False, 'c' * 40)]:
            self.dirty, self.head = dirty, head
            with self.assertRaises(ValueError):
                self.publish()
            self.assertFalse(any(a[0] == 'podman' for a, _ in self.calls))

    def test_each_registry_failure_leaves_no_receipt(self):
        for operation in ('login', 'build', 'push', 'pull', 'image', 'rmi'):
            with self.subTest(operation=operation):
                self.failure = operation
                with self.assertRaises(RuntimeError):
                    self.publish()
                self.assertFalse(self.output.exists())

    def test_wrong_digest_revision_platform_or_entrypoint_rejects_receipt(self):
        original = copy.deepcopy(self.image)
        for field in ('RepoDigests', 'revision', 'Architecture', 'Os', 'Entrypoint'):
            self.image = copy.deepcopy(original)
            if field == 'revision':
                self.image['Config']['Labels']['org.opencontainers.image.revision'] = 'c' * 40
            elif field == 'Entrypoint':
                self.image['Config']['Entrypoint'] = ['/untrusted']
            else:
                self.image[field] = [] if field == 'RepoDigests' else 'wrong'
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.publish()
            self.assertFalse(self.output.exists())

    def test_receipt_cannot_be_overwritten(self):
        self.output.write_text('preserve')
        with self.assertRaises(ValueError):
            self.publish()
        self.assertEqual(self.output.read_text(), 'preserve')
        self.assertEqual(self.calls, [])


if __name__ == '__main__':
    unittest.main()
