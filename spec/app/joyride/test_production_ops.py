"""Real pinned nginx, isolated loopback auth fixture; not live VPN acceptance.

The positive fixture substitutes only the VPN CIDR with loopback, never auth or
routing. The negative fixture retains the exact source configuration. Requires
Podman/OpenSSL; no host ports, managed credentials or production resources.
"""
import base64
import json
from pathlib import Path
import ssl
import subprocess
import tempfile
import time
import unittest
import uuid

from test_private_access import CLIENT, IMAGE, PYTHON, ROOT, run

UPSTREAM = '''
import http.server,json
class Handler(http.server.BaseHTTPRequestHandler):
 def do_GET(self):
  authorized=self.headers.get('Authorization')=='Bearer synthetic-ops-fixture'
  self.send_response(200 if authorized else 401)
  self.end_headers()
  if authorized:
   self.wfile.write(json.dumps({'path':self.path,'headers':dict(self.headers)}).encode())
 def log_message(self,*args): pass
http.server.ThreadingHTTPServer(('127.0.0.1',8001),Handler).serve_forever()
'''


class OpsFixture:
    allow_loopback = False

    @classmethod
    def setUpClass(cls):
        cls.directory = tempfile.TemporaryDirectory(prefix='joyride-production-ops-')
        cls.path = Path(cls.directory.name)
        cls.path.chmod(0o755)
        cls.container = 'joyride-production-ops-' + uuid.uuid4().hex[:12]
        cls.upstream = cls.container + '-upstream'
        cls.network = cls.container + '-network'
        config = (ROOT / 'files/app/joyride/production-ops-nginx.conf').read_text()
        if cls.allow_loopback:
            config = config.replace('allow 172.22.0.0/24;', 'allow 127.0.0.1/32;')
        (cls.path / 'nginx.conf').write_text(config)
        run('openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1', '-subj', '/CN=joyride-ops.eyrie', '-addext', 'subjectAltName=DNS:joyride-ops.eyrie', '-keyout', str(cls.path / 'tls.key'), '-out', str(cls.path / 'tls.crt'))
        (cls.path / 'tls.key').chmod(0o644)  # Disposable synthetic fixture only.
        try:
            architecture = run('podman', 'info', '--format', '{{.Host.Arch}}').stdout.strip()
            for image in (PYTHON, IMAGE):
                run('podman', 'pull', '--platform', 'linux/' + architecture, image)
            run('podman', 'network', 'create', '--internal', cls.network)
            run('podman', 'create', '--name', cls.upstream, '--network', cls.network, '--cap-drop=ALL', PYTHON, 'python', '-u', '-c', UPSTREAM)
            run('podman', 'cp', str(cls.path), cls.upstream + ':/tls')
            run('podman', 'start', cls.upstream)
            run('podman', 'create', '--name', cls.container, '--network', 'container:' + cls.upstream, '--read-only', '--cap-drop=ALL', '--security-opt', 'no-new-privileges', '--user', '10001:10001', '--tmpfs', '/tmp:rw,noexec,nosuid,size=64m,mode=1777', '--entrypoint', 'nginx', IMAGE, '-g', 'daemon off;')
            run('podman', 'cp', str(cls.path), cls.container + ':/tls')
            run('podman', 'cp', str(cls.path / 'nginx.conf'), cls.container + ':/etc/nginx/nginx.conf')
            run('podman', 'start', cls.container)
            for _ in range(30):
                try:
                    status, _ = cls.request('/ops/status')
                    if status == (401 if cls.allow_loopback else 403):
                        break
                except RuntimeError:
                    pass
                time.sleep(0.2)
            else:
                raise RuntimeError(run('podman', 'logs', cls.container).stderr)
        except Exception:
            cls.tearDownClass()
            raise

    @classmethod
    def tearDownClass(cls):
        for name in (cls.container, cls.upstream):
            subprocess.run(['podman', 'rm', '-f', name], capture_output=True, timeout=30)
        subprocess.run(['podman', 'network', 'rm', cls.network], capture_output=True, timeout=30)
        cls.directory.cleanup()

    @classmethod
    def request(cls, path='/ops/status', host='joyride-ops.eyrie', sni='joyride-ops.eyrie', extra='', method='GET'):
        result = json.loads(run('podman', 'exec', cls.upstream, 'python', '-c', CLIENT, '127.0.0.1', path, host, sni, extra, method).stdout)
        if result.get('ssl_error'):
            raise ssl.SSLError('Fixture TLS handshake rejected')
        return result['status'], base64.b64decode(result['data'])


class ProductionOpsAllowed(OpsFixture, unittest.TestCase):
    allow_loopback = True

    def test_bearer_auth_is_not_replaced_by_network_or_identity_headers(self):
        for extra in ('', 'Authorization: Bearer wrong\r\n', 'X-Joyride-Trusted-Test: 1\r\nTailscale-User-Login: joy\r\n'):
            with self.subTest(extra=extra):
                self.assertEqual(self.request(extra=extra)[0], 401)
        self.assertEqual(self.request(extra='Authorization: Bearer synthetic-ops-fixture\r\n')[0], 200)

    def test_fixed_upstream_host_and_header_allowlist(self):
        status, body = self.request(extra='Authorization: Bearer synthetic-ops-fixture\r\nForwarded: forged\r\nX-Forwarded-For: 172.22.0.8\r\nX-Joyride-Trusted-Test: forged\r\nCookie: private-fixture\r\n')
        self.assertEqual(status, 200)
        self.assertIn(b'"Host": "joyride.eyrie"', body)
        self.assertNotIn(b'forged', body)
        self.assertNotIn(b'private-fixture', body)
        self.assertNotIn(b'172.22.0.8', body)

    def test_only_exact_read_only_ops_methods_and_paths(self):
        auth = 'Authorization: Bearer synthetic-ops-fixture\r\n'
        for path in ('/ops/status', '/ops/diagnostics'):
            self.assertEqual(self.request(path=path, extra=auth)[0], 200)
            self.assertEqual(self.request(path=path, extra=auth, method='POST')[0], 405)
        for path in ('/', '/admin/', '/ops/roster', '/ops/deploy', '/delivery/queue', '/ops/status?x=1', '/ops/status?', '/ops/%73tatus', '//ops/status', '/ops/../ops/status'):
            with self.subTest(path=path):
                self.assertEqual(self.request(path=path, extra=auth)[0], 404)

    def test_tls_host_and_sni_are_exact(self):
        self.assertEqual(self.request(host='joyride-ops.eyrie:443')[0], 401)
        for host in ('joyride.eyrie', 'joyride-ops.eyrie.attacker.invalid', 'joyride-ops.eyrie:8001'):
            self.assertEqual(self.request(host=host)[0], 421)
        with self.assertRaises(ssl.SSLError):
            self.request(sni='joyride.eyrie')


class ProductionOpsDenied(OpsFixture, unittest.TestCase):
    def test_original_source_cidr_denies_non_vpn_even_with_bearer_and_spoofing(self):
        for path in ('/ops/status', '/ops/diagnostics'):
            self.assertEqual(self.request(path=path, extra='Authorization: Bearer synthetic-ops-fixture\r\nX-Forwarded-For: 172.22.0.8\r\nForwarded: for=172.22.0.8\r\n')[0], 403)


if __name__ == '__main__':
    unittest.main(verbosity=2)
