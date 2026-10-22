#!/usr/bin/env python3
"""Execute the real publisher with fake Podman; never contact a registry."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / "files/build/publish-image.sh"
IMAGE = "registry.example:5000/nest/stage1/server:candidate-fixture"
DIGEST = "sha256:" + "a" * 64
FAKE = r'''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
with open(os.environ['CALLS'], 'a') as stream:
    stream.write(json.dumps(sys.argv[1:]) + '\n')
if sys.argv[1] == 'push':
    print('push progress on stdout')
    if os.environ.get('FAIL_PUSH'):
        sys.exit(37)
    if not os.environ.get('MISSING_DIGEST'):
        Path(sys.argv[3]).write_text(os.environ['DIGEST'])
    sys.exit(0)
if sys.argv[1] == 'manifest':
    print('{"schemaVersion":2}')
    if sys.argv[2] == 'create' and os.environ.get('FAIL_CREATE'):
        sys.exit(44)
    if sys.argv[2] == 'rm' and os.environ.get('FAIL_REMOVE'):
        sys.exit(45)
    sys.exit(42 if sys.argv[2] == 'add' and os.environ.get('FAIL_INSPECT') else 0)
sys.exit(99)
'''


class PublishImageTest(unittest.TestCase):
    def run_publisher(self, image=IMAGE, **changes):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            podman = root / 'podman'
            podman.write_text(FAKE)
            podman.chmod(0o755)
            env = dict(os.environ, PATH=str(root) + os.pathsep + os.environ['PATH'],
                       TMPDIR=temporary, CALLS=str(root / 'calls'), DIGEST=DIGEST)
            env.update(changes)
            result = subprocess.run(['bash', str(SCRIPT), image], env=env, capture_output=True, text=True, check=False)
            calls = [json.loads(line) for line in (root / 'calls').read_text().splitlines()] if (root / 'calls').exists() else []
            self.assertFalse(list(root.glob('nest-image-publication.*')), 'private digest staging must be removed')
            return result, calls

    def test_verified_content_addressed_result_and_separate_diagnostics(self):
        result, calls = self.run_publisher()
        expected = 'registry.example:5000/nest/stage1/server@' + DIGEST
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, expected + '\n')
        self.assertIn('push progress', result.stderr)
        self.assertEqual(calls[0][0:2], ['push', '--digestfile'])
        self.assertEqual(calls[0][-1], IMAGE)
        self.assertEqual(calls[1][0:2], ['manifest', 'create'])
        probe = calls[1][2]
        self.assertEqual(calls[2], ['manifest', 'add', probe, 'docker://' + expected])
        self.assertEqual(calls[3], ['manifest', 'rm', probe])
        self.assertEqual(len(calls), 4)

    def test_push_failure_preserves_native_exit_and_never_inspects(self):
        result, calls = self.run_publisher(FAIL_PUSH='1')
        self.assertEqual(result.returncode, 37)
        self.assertEqual(result.stdout, '')
        self.assertEqual(len(calls), 1)

    def test_readback_failure_emits_no_result(self):
        result, calls = self.run_publisher(FAIL_INSPECT='1')
        self.assertEqual(result.returncode, 42)
        self.assertEqual(result.stdout, '')
        self.assertEqual(len(calls), 4)
        self.assertEqual(calls[-1][0:2], ['manifest', 'rm'])

    def test_bad_or_missing_digest_never_becomes_reference(self):
        for changes in ({'DIGEST': 'sha256:bad'}, {'DIGEST': DIGEST + '\nextra'}, {'MISSING_DIGEST': '1'}):
            # DIGEST overrides the fixture default explicitly.
            with self.subTest(changes=changes):
                result, calls = self.run_publisher(**changes)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, '')
                self.assertEqual(len(calls), 1)

    def test_create_collision_never_removes_an_unowned_manifest(self):
        result, calls = self.run_publisher(FAIL_CREATE='1')
        self.assertEqual(result.returncode, 44)
        self.assertEqual(result.stdout, '')
        self.assertEqual(len(calls), 2)
        self.assertEqual(calls[-1][0:2], ['manifest', 'create'])

    def test_failed_owned_manifest_cleanup_does_not_report_success(self):
        result, calls = self.run_publisher(FAIL_REMOVE='1')
        self.assertEqual(result.returncode, 45)
        self.assertEqual(result.stdout, '')
        self.assertEqual(calls[-2][0:2], ['manifest', 'rm'])
        self.assertEqual(calls[-1], calls[-2])

    def test_invalid_input_has_no_podman_side_effect(self):
        for image in ('localhost/image', 'image:tag', IMAGE + ';touch /unsafe', IMAGE + '\n', ''):
            with self.subTest(image=image):
                result, calls = self.run_publisher(image)
                self.assertEqual(result.returncode, 2)
                self.assertEqual(calls, [])


if __name__ == '__main__':
    unittest.main()
