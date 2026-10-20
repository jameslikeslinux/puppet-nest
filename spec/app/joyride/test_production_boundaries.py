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
                self.assertNotIn(resource['kind'], ('Secret', 'Role', 'RoleBinding', 'ServiceAccount', 'Job'))
                if resource['kind'] == 'CronJob':
                    self.assertEqual(resource['metadata']['name'], 'joyride-monitor')
                    self.assertIs(resource['spec']['suspend'], True)
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
            if deployment['metadata']['name'] != 'joyride':
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

    def test_serial_initialization_is_scoped_to_production_storage(self):
        pod = self.resources['app']['spec']['template']['spec']
        migrate, basemap = pod['initContainers']
        self.assertEqual([c['name'] for c in pod['initContainers']], ['migrate', 'basemap'])
        self.assertEqual(migrate['command'], ['python', 'manage.py', 'migrate', '--noinput'])
        self.assertEqual(basemap['command'], ['python', '/platform/bootstrap.py'])
        web = pod['containers'][0]
        for initializer in (migrate, basemap):
            self.assertEqual(initializer['image'], web['image'])
            self.assertEqual(initializer['securityContext'], web['securityContext'])
            self.assertEqual(initializer['env'], web['env'])
            self.assertEqual(initializer['envFrom'], web['envFrom'])
            self.assertEqual(initializer['resources'], web['resources'])
        self.assertEqual(migrate['volumeMounts'], [{'name': 'tmp', 'mountPath': '/data/tmp'}])
        volumes = {v['name']: v for v in pod['volumes']}
        self.assertEqual(volumes['data']['persistentVolumeClaim'], {'claimName': 'joyride-data'})
        self.assertEqual(volumes['scripts']['configMap'], {'name': 'joyride-bootstrap', 'defaultMode': 0o444})
        self.assertEqual(volumes['pull']['secret'], {'secretName': 'joyride-pull'})
        self.assertEqual(self.resources['scripts']['binaryData'], {
            'bootstrap.py': '%{nest::service::joyride::bootstrap_script_base64}'})
        mounts = {m['name']: m for m in basemap['volumeMounts']}
        self.assertIs(mounts['scripts']['readOnly'], True)
        self.assertIs(mounts['pull']['readOnly'], True)
        self.assertFalse(mounts['data'].get('readOnly', False))
        for deployment in self.deployments:
            runtime_pod = deployment['spec']['template']['spec']
            for container in runtime_pod['containers']:
                self.assertTrue({'pull', 'scripts'}.isdisjoint(m['name'] for m in container['volumeMounts']))
            if deployment['metadata']['name'] != 'joyride':
                self.assertTrue({'pull', 'scripts'}.isdisjoint(v['name'] for v in runtime_pod['volumes']))

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

    def test_monitor_has_no_runtime_credentials_or_privileged_network_path(self):
        job = self.resources['monitor']['spec']
        self.assertIs(job['suspend'], True)
        self.assertEqual(job['concurrencyPolicy'], 'Forbid')
        pod = job['jobTemplate']['spec']['template']['spec']
        self.assertIs(pod['automountServiceAccountToken'], False)
        self.assertEqual(pod['volumes'], [{'name': 'scripts', 'configMap': {'name': 'joyride-monitor'}}])
        container, = pod['containers']
        self.assertEqual(container['image'], "%{lookup('joyride_image')}")
        self.assertEqual(container['command'], ['python', '-B', '/platform/monitor.py', '--environment', 'production'])
        self.assertNotIn('env', container)
        self.assertNotIn('envFrom', container)
        self.assertIs(container['securityContext']['readOnlyRootFilesystem'], True)
        self.assertEqual(self.resources['monitor_scripts']['binaryData'], {
            'monitor.py': '%{nest::service::joyride::monitor_script_base64}'})
        self.assertEqual(self.resources['monitor_policy']['spec'], {
            'podSelector': {'matchLabels': {'app': 'joyride'}}, 'policyTypes': ['Ingress'],
            'ingress': [{'from': [{'podSelector': {'matchLabels': {'app': 'joyride-monitor'}}}],
                         'ports': [{'protocol': 'TCP', 'port': 8000}]}]})
        rule, = self.resources['alert_rules']['spec']['groups'][0]['rules']
        self.assertIn('kube_cronjob_spec_suspend{namespace="joyride",cronjob="joyride-monitor"} == 0', rule['expr'])
        self.assertIn('unless on(namespace,cronjob)', rule['expr'])

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
