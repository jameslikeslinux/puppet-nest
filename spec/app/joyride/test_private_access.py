"""Exercise the real pinned nginx listener without cluster credentials.

Run with python3 spec/app/joyride/test_private_access.py. Requires Podman/OpenSSL.
Upstreams are explicit local fixtures, not substitutes for live app acceptance.
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
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[3]
IMAGE = "docker.io/nginxinc/nginx-unprivileged@sha256:f5116ed4606f3eb015dd4a8e28cb9b351476dc0ad4bc6e9f93b19cec130cdf03"
PYTHON = "docker.io/library/python@sha256:a1165e272e578941b84abc79e4ab38a0305cd12803a5c4247979ac7655f4d641"
UPSTREAM = '''
import http.server, json
class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(401 if self.path.startswith('/ops/') and not self.headers.get('Authorization') else 200)
        self.end_headers()
        self.wfile.write(json.dumps({'path':self.path,'headers':dict(self.headers)}).encode())
    def log_message(self, format, *args):
        pass
http.server.ThreadingHTTPServer(('0.0.0.0', 8000), Handler).serve_forever()
'''
CLIENT = '''
import base64, json, socket, ssl, sys
target, path, host, sni, extra = sys.argv[1:]
try:
    context = ssl.create_default_context(cafile='/tls/tls.crt')
    with socket.create_connection((target,8443),timeout=5) as raw:
        with context.wrap_socket(raw,server_hostname=sni) as sock:
            sock.sendall(('GET '+path+' HTTP/1.1\\r\\nHost: '+host+'\\r\\nConnection: close\\r\\n'+extra+'\\r\\n').encode())
            data=b''
            while chunk := sock.recv(65536):
                data += chunk
    print(json.dumps({'status':int(data.split(b' ')[1]), 'data':base64.b64encode(data).decode()}))
except ssl.SSLError:
    print(json.dumps({'ssl_error':True}))
'''


def run(*args):
    result = subprocess.run(args, capture_output=True, text=True, timeout=120)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result


class PrivateAccess(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.directory = tempfile.TemporaryDirectory(prefix="joyride-private-access-")
        cls.path = Path(cls.directory.name)
        cls.path.chmod(0o755)
        cls.container = "joyride-access-test-" + uuid.uuid4().hex[:12]
        cls.upstream = cls.container + "-upstream"
        cls.network = cls.container + "-network"
        config = (ROOT / "files/app/joyride/test-access-nginx.conf").read_text()
        for name, port in (("web", 8000), ("ops", 8001)):
            config = config.replace(f"joyride-test-{name}.test.svc.cluster.local:{port}", f"{cls.upstream}:8000")
        (cls.path / "nginx.conf").write_text(config)
        run("openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1", "-subj", "/CN=joyride-test.eyrie", "-addext", "subjectAltName=DNS:joyride-test.eyrie", "-keyout", str(cls.path / "tls.key"), "-out", str(cls.path / "tls.crt"))
        (cls.path / "tls.key").chmod(0o644)  # Disposable fixture, never a managed key.
        try:
            # No host networking, published ports or bind mounts: works with remote CI Podman.
            architecture = run("podman", "info", "--format", "{{.Host.Arch}}").stdout.strip()
            for image in (PYTHON, IMAGE):
                run("podman", "pull", "--platform", "linux/" + architecture, image)
            run("podman", "network", "create", "--internal", cls.network)
            run("podman", "create", "--name", cls.upstream, "--network", cls.network, "--cap-drop=ALL", "--security-opt", "no-new-privileges", PYTHON, "python", "-u", "-c", UPSTREAM)
            run("podman", "cp", str(cls.path), cls.upstream + ":/tls")
            run("podman", "start", cls.upstream)
            upstream_info = json.loads(run("podman", "inspect", cls.upstream).stdout)[0]
            upstream_ip = upstream_info["NetworkSettings"]["Networks"][cls.network]["IPAddress"]
            (cls.path / "nginx.conf").write_text(config.replace(cls.upstream + ":8000", upstream_ip + ":8000"))
            run("podman", "create", "--name", cls.container, "--network", cls.network, "--read-only", "--cap-drop=ALL", "--security-opt", "no-new-privileges", "--user", "101:101", "--tmpfs", "/tmp:rw,noexec,nosuid,size=64m,mode=1777", "--entrypoint", "nginx", IMAGE, "-g", "daemon off;")
            run("podman", "cp", str(cls.path), cls.container + ":/tls")
            run("podman", "cp", str(cls.path / "nginx.conf"), cls.container + ":/etc/nginx/nginx.conf")
            run("podman", "start", cls.container)
            nginx_info = json.loads(run("podman", "inspect", cls.container).stdout)[0]
            cls.address = nginx_info["NetworkSettings"]["Networks"][cls.network]["IPAddress"]
            for _ in range(30):
                try:
                    probe = run("podman", "exec", cls.upstream, "python", "-c", CLIENT, cls.address, "/", "joyride-test.eyrie", "joyride-test.eyrie", "")
                    if json.loads(probe.stdout).get("status") == 200:
                        break
                except RuntimeError:
                    pass
                time.sleep(0.2)
            else:
                logs = run("podman", "logs", cls.container)
                raise RuntimeError(logs.stdout + logs.stderr)
        except Exception:
            cls.cleanup()
            cls.directory.cleanup()
            raise

    @classmethod
    def cleanup(cls):
        for name in (cls.container, cls.upstream):
            subprocess.run(["podman", "rm", "-f", name], capture_output=True, timeout=30)
        subprocess.run(["podman", "network", "rm", cls.network], capture_output=True, timeout=30)

    @classmethod
    def tearDownClass(cls):
        cls.cleanup()
        cls.directory.cleanup()

    def request(self, path="/", host="joyride-test.eyrie", sni="joyride-test.eyrie", extra=""):
        result = json.loads(run("podman", "exec", self.upstream, "python", "-c", CLIENT, self.address, path, host, sni, extra).stdout)
        if result.get("ssl_error"):
            raise ssl.SSLError("Fixture TLS handshake rejected")
        return result["status"], base64.b64decode(result["data"])

    def test_home(self):
        self.assertEqual(self.request()[0], 200)

    def test_exact_origin_with_standard_port(self):
        self.assertEqual(self.request(host="joyride-test.eyrie:443")[0], 200)

    def test_shared_ingress_host_is_not_forwarded(self):
        self.assertEqual(self.request(host="gitlab-test.eyrie")[0], 421)

    def test_host_suffix_is_not_accepted(self):
        self.assertEqual(self.request(host="joyride-test.eyrie.attacker.invalid")[0], 421)

    def test_wrong_port_is_not_accepted(self):
        self.assertEqual(self.request(host="joyride-test.eyrie:8001")[0], 421)

    def test_wrong_sni_fails_handshake(self):
        with self.assertRaises(ssl.SSLError):
            self.request(sni="gitlab-test.eyrie")

    def test_private_controller_is_absent(self):
        self.assertEqual(self.request(path="/delivery/queue")[0], 404)

    def test_roster_and_admin_are_absent(self):
        for path in ("/ops/roster", "/admin/", "/ops/arbitrary"):
            with self.subTest(path=path):
                self.assertEqual(self.request(path=path)[0], 404)

    def test_status_still_needs_application_auth(self):
        self.assertEqual(self.request(path="/ops/status")[0], 401)
        self.assertEqual(self.request(path="/ops/status", extra="Authorization: Bearer fixture-only\r\n")[0], 200)

    def test_forwarded_headers_are_replaced(self):
        status, data = self.request(extra="Forwarded: host=other.invalid\r\nX-Forwarded-Proto: http\r\nX-Forwarded-Host: other.invalid\r\nX-Forwarded-For: 1.2.3.4\r\n")
        self.assertEqual(status, 200)
        self.assertIn(b'"Host": "joyride-test.eyrie"', data)
        self.assertIn(b'"X-Forwarded-Proto": "https"', data)
        self.assertNotIn(b"other.invalid", data)
        self.assertNotIn(b"1.2.3.4", data)


class RouterBoundary(unittest.TestCase):
    def test_tailnet_grants_exact_destinations_only(self):
        policy = json.loads((ROOT / "files/tailscale/luna-gitlab.json").read_text())
        self.assertEqual(policy["acls"], [])
        self.assertEqual(policy["ssh"], [])
        self.assertEqual(policy["autoApprovers"], {})
        self.assertEqual(policy["grants"], [
            {"src": ["tag:luna-gitlab"], "dst": ["172.21.2.1/32"], "ip": ["tcp:22"]},
            {"src": ["tag:luna-gitlab"], "dst": ["172.21.1.3/32"], "ip": ["tcp:443"]},
        ])

    def test_firewalld_matches_tailnet_without_broad_accept(self):
        policy = ET.parse(ROOT / "files/tailscale/luna-gitlab.xml").getroot()
        self.assertEqual(policy.attrib["target"], "DROP")
        accepted = set()
        masqueraded = set()
        for rule in policy.findall("rule"):
            source = rule.find("source")
            target = rule.find("destination")
            assert source is not None and target is not None
            self.assertEqual(source.attrib["address"], "100.127.2.74/32")
            destination = target.attrib["address"]
            if rule.find("accept") is not None:
                port = rule.find("port")
                assert port is not None
                self.assertEqual(port.attrib["protocol"], "tcp")
                accepted.add((destination, port.attrib["port"]))
            elif rule.find("masquerade") is not None:
                masqueraded.add(destination)
            else:
                self.fail("Unexpected firewall rule")
        self.assertEqual(accepted, {("172.21.2.1/32", "22"), ("172.21.1.3/32", "443")})
        self.assertEqual(masqueraded, {"172.21.2.1/32", "172.21.1.3/32"})


if __name__ == "__main__":
    unittest.main(verbosity=2)
