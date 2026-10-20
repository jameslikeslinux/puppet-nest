"""Real Apache candidate with synthetic TLS origin; no gateway/cluster mutation.

Only listen addresses, certificate paths and origin address are fixture-local.
No managed key, host networking, bind mount or published port is used.
"""
import base64
import json
from pathlib import Path
import subprocess
import tempfile
import time
import unittest
import uuid

from test_private_access import PYTHON, ROOT, run

HTTPD = 'mirror.gcr.io/library/httpd@sha256:cc4c94eb4e9c3d94ac2147cb9ce8057096362de83fa12b7aeecd4c0c3d5d1f21'
UPSTREAM = '''
import http.server,json,ssl
class Handler(http.server.BaseHTTPRequestHandler):
 def do_GET(self):
  self.send_response(200)
  self.end_headers()
  self.wfile.write(json.dumps({'path':self.path,'headers':dict(self.headers)}).encode())
 do_POST=do_GET
 def log_message(self,*args): pass
context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain('/tls/origin.crt','/tls/origin.key')
server=http.server.ThreadingHTTPServer(('127.0.0.1',9443),Handler)
server.socket=context.wrap_socket(server.socket,server_side=True)
server.serve_forever()
'''
CLIENT = '''
import base64,json,socket,ssl,sys
port,path,host,sni,extra,method=sys.argv[1:]
with socket.create_connection(('127.0.0.1',int(port)),timeout=5) as raw:
 context=ssl.create_default_context(cafile='/tls/gateway.crt')
 with context.wrap_socket(raw,server_hostname=sni) if sni else raw as sock:
  sock.sendall((method+' '+path+' HTTP/1.1\\r\\nHost: '+host+'\\r\\nConnection: close\\r\\n'+extra+'\\r\\n').encode())
  data=b''
  while chunk:=sock.recv(65536): data+=chunk
print(json.dumps({'status':int(data.split(b' ')[1]),'data':base64.b64encode(data).decode()}))
'''


class GatewayFixture:
    origin_name = 'joyride.eyrie'
    trust_origin = True

    @classmethod
    def setUpClass(cls):
        cls.directory = tempfile.TemporaryDirectory(prefix='joyride-gateway-')
        cls.path = Path(cls.directory.name)
        cls.path.chmod(0o755)
        cls.upstream = 'joyride-gateway-' + uuid.uuid4().hex[:12]
        cls.container = cls.upstream + '-apache'
        cls.network = cls.upstream + '-network'
        for name, names in (('gateway', 'DNS:joyridedc.com,DNS:www.joyridedc.com'),
                            ('origin', 'DNS:' + cls.origin_name)):
            run('openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1',
                '-subj', '/CN=' + names[4:].split(',')[0], '-addext', 'subjectAltName=' + names,
                '-keyout', str(cls.path / (name + '.key')), '-out', str(cls.path / (name + '.crt')))
            (cls.path / (name + '.key')).chmod(0o644)  # Synthetic fixture only.
        config = (ROOT / 'files/app/joyride/production-gateway-apache.conf').read_text()
        config = config.replace('45.77.156.204:80 [2001:19f0:1000:e1dc::204]:80', '*:8080')
        config = config.replace('45.77.156.204:443 [2001:19f0:1000:e1dc::204]:443', '*:8443')
        config = config.replace('/etc/letsencrypt/live/joyridedc.com/fullchain.pem', '/tls/gateway.crt')
        config = config.replace('/etc/letsencrypt/live/joyridedc.com/privkey.pem', '/tls/gateway.key')
        config = config.replace('/etc/ssl/certs/ca-certificates.crt',
                                '/tls/origin.crt' if cls.trust_origin else '/tls/gateway.crt')
        config = config.replace('https://joyride.eyrie/', 'https://joyride.eyrie:9443/')
        prefix = '''ServerRoot /usr/local/apache2
ServerName fixture.invalid
Listen 8080
Listen 8443
PidFile /tmp/httpd.pid
ErrorLog /proc/self/fd/2
LogLevel crit
User daemon
Group daemon
'''
        for module, library in (('mpm_event', 'mod_mpm_event'), ('authz_core', 'mod_authz_core'),
                                ('log_config', 'mod_log_config'),
                                ('authz_host', 'mod_authz_host'), ('unixd', 'mod_unixd'),
                                ('socache_shmcb', 'mod_socache_shmcb'), ('ssl', 'mod_ssl'),
                                ('rewrite', 'mod_rewrite'), ('headers', 'mod_headers'),
                                ('proxy', 'mod_proxy'), ('proxy_http', 'mod_proxy_http')):
            prefix += f'LoadModule {module}_module modules/{library}.so\n'
        (cls.path / 'httpd.conf').write_text(prefix + config)
        try:
            architecture = run('podman', 'info', '--format', '{{.Host.Arch}}').stdout.strip()
            for image in (PYTHON, HTTPD):
                run('podman', 'pull', '--platform', 'linux/' + architecture, image)
            run('podman', 'network', 'create', '--internal', cls.network)
            run('podman', 'create', '--name', cls.upstream, '--network', cls.network,
                '--add-host', 'joyride.eyrie:127.0.0.1', '--cap-drop=ALL', PYTHON, 'python', '-u', '-c', UPSTREAM)
            run('podman', 'cp', str(cls.path), cls.upstream + ':/tls')
            run('podman', 'start', cls.upstream)
            run('podman', 'create', '--name', cls.container, '--network', 'container:' + cls.upstream,
                '--read-only', '--cap-drop=ALL',
                '--security-opt', 'no-new-privileges', '--user', '10001:10001',
                '--tmpfs', '/tmp:rw,noexec,nosuid,size=32m,mode=1777',
                '--entrypoint', 'httpd', HTTPD, '-f', '/tls/httpd.conf', '-DFOREGROUND')
            run('podman', 'cp', str(cls.path), cls.container + ':/tls')
            run('podman', 'start', cls.container)
            for _ in range(30):
                try:
                    status = cls.request()[0]
                    if status in ((200,) if cls.origin_name == 'joyride.eyrie' and cls.trust_origin else (500, 502)):
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
    def request(cls, path='/', host='joyridedc.com', sni='joyridedc.com', extra='', method='GET', port='8443'):
        result = json.loads(run('podman', 'exec', cls.upstream, 'python', '-c', CLIENT,
                                port, path, host, sni, extra, method).stdout)
        return result['status'], base64.b64decode(result['data'])


class ProductionGateway(GatewayFixture, unittest.TestCase):
    def test_public_web_preserves_session_csrf_and_range_not_trust_headers(self):
        status, body = self.request('/api/me', extra='Cookie: session=synthetic\r\nX-CSRFToken: synthetic\r\nRange: bytes=0-7\r\nOrigin: https://joyridedc.com\r\nX-Forwarded-Proto: http\r\nForwarded: forged\r\nX-Forwarded-For: forged\r\nX-Forwarded-Host: forged\r\nX-Real-IP: forged\r\nTailscale-User-Login: forged\r\nTailscale-User-Name: forged\r\nX-Joyride-Trusted-Test: forged\r\n')
        self.assertEqual(status, 200)
        self.assertNotIn(b'forged', body)
        self.assertIn(b'"Host": "joyride.eyrie:9443"', body)
        for expected in (b'session=synthetic', b'"X-CSRFToken": "synthetic"', b'bytes=0-7',
                         b'"X-Forwarded-Proto": "https"', b'https://joyridedc.com'):
            self.assertIn(expected, body)

    def test_private_paths_never_reach_upstream(self):
        for path in ('/ops', '/ops/status', '/OPS/status', '/admin/', '/delivery/queue',
                     '//ops/status', '/%6fps/status', '/x/../ops/status', '/ops;anything',
                     '/ops%2fstatus', '/%256fps/status'):
            with self.subTest(path=path):
                status, body = self.request(path)
                # A double-encoded segment is not an app route; Apache must not
                # decode it twice. The origin still has no privileged listener.
                if path == '/%256fps/status':
                    self.assertEqual(status, 200)
                    self.assertIn(b'"path": "/%256fps/status"', body)
                else:
                    self.assertIn(status, (400, 404))

    def test_canonical_redirect_and_query_are_fixed_not_host_derived(self):
        for port, sni, host in (('8443', 'www.joyridedc.com', 'www.joyridedc.com'),
                                ('8080', '', 'www.joyridedc.com'), ('8080', '', 'joyridedc.com')):
            status, body = self.request('/member/?next=ride', host=host, sni=sni, port=port)
            self.assertEqual(status, 301)
            self.assertIn(b'Location: https://joyridedc.com/member/?next=ride\r\n', body)

    def test_host_sni_mismatch_and_unconfigured_hosts_are_denied(self):
        for host, sni in (('evil.invalid', 'joyridedc.com'), ('joyride.eyrie', 'joyridedc.com'),
                          ('joyridedc.com:8001', 'joyridedc.com'),
                          ('www.joyridedc.com', 'joyridedc.com'), ('joyridedc.com', 'www.joyridedc.com')):
            self.assertIn(self.request(host=host, sni=sni)[0], (400, 421))
        self.assertIn(self.request(host='evil.invalid', sni='', port='8080')[0], (400, 421))


class ProductionGatewayWrongOrigin(GatewayFixture, unittest.TestCase):
    origin_name = 'wrong-origin.invalid'

    def test_trusted_certificate_for_wrong_origin_name_is_rejected(self):
        status, body = self.request()
        self.assertIn(status, (500, 502))
        self.assertNotIn(b'"headers":', body)


class ProductionGatewayUntrustedOrigin(GatewayFixture, unittest.TestCase):
    trust_origin = False

    def test_correct_name_with_untrusted_certificate_is_rejected(self):
        status, body = self.request()
        self.assertIn(status, (500, 502))
        self.assertNotIn(b'"headers":', body)


if __name__ == '__main__':
    unittest.main(verbosity=2)
