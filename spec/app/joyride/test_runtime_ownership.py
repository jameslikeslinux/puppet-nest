"""Infrastructure ownership/admission contract; no app runtime execution in CI."""
from pathlib import Path
import unittest
import yaml

ROOT = Path(__file__).resolve().parents[3]


class RuntimeOwnership(unittest.TestCase):
    def test_nest_ci_has_no_application_release(self):
        ci = yaml.safe_load((ROOT / '.gitlab-ci.yml').read_text())
        self.assertFalse(any(name.startswith('Publish Joyride') for name in ci))
        self.assertNotIn('trigger:', (ROOT / '.gitlab-ci.yml').read_text())
        for name in ('release_informational.py', 'release_evidence_runtime.py',
                     'Containerfile.info', 'Containerfile.evidence', 'bootstrap.py',
                     'backup.py', 'monitor.py', 'installed_test_producer.py'):
            self.assertFalse((ROOT / 'files/app/joyride' / name).exists())

    def test_operational_image_is_independently_pinned(self):
        data = yaml.safe_load((ROOT / 'data/kubernetes/app/joyride.yaml').read_text())
        self.assertRegex(data['joyride_operations_image'],
                         r'^registry.gitlab.joyfullee.me/joy/joyride/app@sha256:[0-9a-f]{64}$')

    def test_self_service_delivery_has_only_exact_test_workload_authority(self):
        data = yaml.safe_load((ROOT / 'data/kubernetes/app/joyride/test.yaml').read_text())
        resources = data['resources']
        self.assertEqual(resources['delivery_role']['rules'], [
            {'apiGroups': ['apps'], 'resources': ['deployments'],
             'resourceNames': ['joyride-test'], 'verbs': ['get', 'patch']},
            {'apiGroups': [''], 'resources': ['configmaps'],
             'resourceNames': ['joyride-test-delivery-journal'], 'verbs': ['get', 'update']},
        ])
        self.assertEqual(resources['delivery_role']['metadata']['namespace'], 'test')
        self.assertNotIn('data', resources['delivery_journal'])
        controller = resources['delivery_controller']['spec']
        self.assertEqual(controller['concurrencyPolicy'], 'Forbid')
        pod = controller['jobTemplate']['spec']['template']['spec']
        self.assertEqual(pod['serviceAccountName'], 'joyride-test-delivery')
        self.assertNotIn('envFrom', pod['containers'][0])
        self.assertFalse(resources['artifact_import']['spec']['jobTemplate']['spec']
                         ['template']['spec']['automountServiceAccountToken'])
        self.assertEqual(set(resources['scripts']['binaryData']),
                         {'import_artifacts.py', 'test_delivery_controller.py'})
        self.assertRegex(data['joyride_image'], r'@sha256:[0-9a-f]{64}$')
        self.assertFalse(resources['app']['spec']['template']['spec']['automountServiceAccountToken'])

    def test_backup_admission_has_no_authority_and_helper_is_read_only(self):
        for path in ('data/kubernetes/service/joyride-test.yaml',
                     'data/kubernetes/app/joyride/joyride.yaml'):
            with self.subTest(path=path):
                data = yaml.safe_load((ROOT / path).read_text())
                pod = data['resources']['backup']['spec']['jobTemplate']['spec']['template']['spec']
                initializer, = pod['initContainers']
                self.assertEqual(initializer['image'], "%{lookup('joyride_operations_image')}")
                self.assertEqual(initializer['volumeMounts'], [{'name': 'scripts', 'mountPath': '/trusted'}])
                self.assertNotIn('env', initializer)
                self.assertNotIn('envFrom', initializer)
                self.assertIs(pod['automountServiceAccountToken'], False)
                self.assertIs(initializer['securityContext']['runAsNonRoot'], True)
                self.assertEqual(initializer['command'][:4], ['python', '-I', '-B', '-c'])
                self.assertIn('0bd5c397f068b7e9eed784ce48afcd0abf4eeb4ae3b5a11c53aaa04939415f5c', initializer['command'][-1])
                self.assertIn('os.O_EXCL', initializer['command'][-1])
                backup, = pod['containers']
                self.assertEqual(backup['command'][2], '/trusted/backup.py')
                self.assertIs(next(m for m in backup['volumeMounts'] if m['name'] == 'scripts')['readOnly'], True)
                self.assertEqual(next(v for v in pod['volumes'] if v['name'] == 'scripts')['emptyDir'], {'sizeLimit': '1Mi'})

if __name__ == '__main__':
    unittest.main()
