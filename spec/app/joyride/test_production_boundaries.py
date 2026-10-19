"""Dormant production integration boundaries, not deployed acceptance.

Run with python3 spec/app/joyride/test_production_boundaries.py. Requires PyYAML.
The TEST-only Puppet compile guard must remain closed during this preparation.
"""
from pathlib import Path
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[3]


class ProductionBoundaries(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = (ROOT / 'data/kubernetes/app/joyride/joyride.yaml').read_text()
        cls.candidate = yaml.safe_load(cls.source)
        cls.resources = cls.candidate['resources']
        cls.deployments = [r for r in cls.resources.values() if r.get('kind') == 'Deployment']

    def test_namespace_and_no_test_operational_authority(self):
        self.assertEqual(self.candidate['runtime_environment'], 'production')
        self.assertEqual(self.candidate['service_name'], 'joyride')
        for resource in self.resources.values():
            if resource:
                self.assertEqual(resource['metadata']['namespace'], 'joyride')
                self.assertNotIn(resource['kind'], ('Secret', 'Role', 'RoleBinding', 'ServiceAccount', 'CronJob', 'Job'))
        self.assertNotIn('joyride-test', self.source)
        self.assertNotIn('8002', self.source)
        self.assertNotIn('172.21.1.3', self.source)
        self.assertEqual(self.resources['backup'], {})
        self.assertEqual(self.resources['restore'], {})

    def test_immutable_same_artifact_and_inert_deployments(self):
        test = yaml.safe_load((ROOT / 'data/kubernetes/app/joyride/test.yaml').read_text())
        self.assertEqual(self.candidate['joyride_image'], test['joyride_image'])
        self.assertRegex(self.candidate['joyride_image'], r'@sha256:[0-9a-f]{64}$')
        self.assertEqual(len(self.deployments), 3)
        for deployment in self.deployments:
            self.assertEqual(deployment['spec']['replicas'], 0)
            pod = deployment['spec']['template']['spec']
            self.assertIs(pod['automountServiceAccountToken'], False)
            self.assertNotIn('initContainers', pod)
            self.assertEqual(pod['imagePullSecrets'], [{'name': 'joyride-pull'}])
            for container in pod['containers']:
                self.assertEqual(container['image'], "%{lookup('joyride_image')}")
                self.assertIs(container['securityContext']['readOnlyRootFilesystem'], True)
                self.assertIs(container['securityContext']['allowPrivilegeEscalation'], False)

    def test_public_origin_only_reaches_web(self):
        ingress = self.resources['ingress']['spec']
        self.assertEqual(ingress['ingressClassName'], 'contour')
        self.assertEqual(ingress['rules'], [{
            'host': 'joyride.eyrie', 'http': {'paths': [{
                'path': '/', 'pathType': 'Prefix', 'backend': {'service': {
                    'name': 'joyride-web', 'port': {'number': 8000}}}}]}}])
        self.assertEqual(self.resources['web']['spec']['selector'], {'app': 'joyride'})
        self.assertEqual(self.resources['ops']['spec']['selector'], {'app': 'joyride-ops'})
        web = self.resources['app']['spec']['template']['spec']['containers']
        self.assertEqual([c['name'] for c in web], ['web'])
        self.assertIn('joyride.wsgi:application', web[0]['command'])
        for resource in self.resources.values():
            if resource.get('kind') == 'Service':
                self.assertNotIn(resource['spec'].get('type'), ('NodePort', 'LoadBalancer'))

    def test_network_boundary_separates_ops_from_shared_ingress(self):
        self.assertEqual(self.resources['ops_policy']['spec'], {
            'podSelector': {'matchLabels': {'app': 'joyride-ops'}},
            'policyTypes': ['Ingress'], 'ingress': []})
        self.assertEqual(self.resources['worker_policy']['spec']['ingress'], [])
        self.assertEqual(self.resources['web_policy']['spec']['ingress'], [{
            'from': [{'namespaceSelector': {'matchLabels': {
                'kubernetes.io/metadata.name': 'projectcontour'}},
                'podSelector': {'matchLabels': {'app.kubernetes.io/component': 'envoy'}}}],
            'ports': [{'protocol': 'TCP', 'port': 8000}]}])

    def test_credential_consumers_are_explicit_and_environment_local(self):
        actual = {}
        for deployment in self.deployments:
            for container in deployment['spec']['template']['spec']['containers']:
                self.assertEqual(container['envFrom'], [{'configMapRef': {'name': 'joyride-config'}}])
                actual[container['name']] = {item['name']: item['valueFrom']['secretKeyRef'] for item in container['env']}
        common = {'DJANGO_SECRET_KEY': {'name': 'joyride-runtime', 'key': 'DJANGO_SECRET_KEY'},
                  'DATABASE_URL': {'name': 'joyride-cnpg-app', 'key': 'uri'}}
        self.assertEqual(actual, {
            'web': common,
            'worker': dict(common, WMATA_API_KEY={'name': 'joyride-upstream', 'key': 'WMATA_API_KEY'}),
            'ops': dict(common, OPS_TOKEN={'name': 'joyride-ops-auth', 'key': 'OPS_TOKEN'})})
        config = self.resources['config']['data']
        self.assertEqual(config['MAIL_ENABLED'], '0')
        self.assertEqual(config['STRIPE_MODE'], 'disabled')
        self.assertEqual(config['OPS_SCOPES'], 'status,diagnostics,member:read')
        self.assertEqual(config['ALLOWED_HOSTS'], 'joyride.eyrie')

    def test_storage_does_not_reference_test_claims_or_database(self):
        self.assertEqual(self.resources['database']['metadata']['name'], 'joyride-cnpg')
        self.assertEqual(self.resources['storage']['metadata']['name'], 'joyride-data')
        for deployment in self.deployments:
            volumes = deployment['spec']['template']['spec']['volumes']
            self.assertEqual(volumes[0]['persistentVolumeClaim'], {'claimName': 'joyride-data'})

    def test_activation_still_refused_by_common_class(self):
        guard = (ROOT / 'manifests/service/joyride.pp').read_text()
        self.assertIn("$nest::kubernetes::namespace != 'test'", guard)
        self.assertIn("$nest::kubernetes::service != 'joyride-test'", guard)
        self.assertIn("fail('Joyride currently supports only service joyride-test", guard)
        self.assertFalse((ROOT / 'plans/eyrie/deploy_joyride.yaml').exists())
        gateway = (ROOT / 'data/host/gateway.yaml').read_text()
        self.assertNotIn('joyridedc.com', gateway)


if __name__ == '__main__':
    unittest.main()
